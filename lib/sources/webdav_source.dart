// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../core/models/library_models.dart';
import '../core/models/media_models.dart';
import 'local_source.dart' show formatBytes;
import 'media_source.dart';
import 'source_config.dart';

/// WebDAV shares (Nextcloud, ownCloud, rclone serve, Apache mod_dav).
///
/// Listing is a hand-written `PROPFIND` rather than a client package: the only
/// operation the app needs is a directory listing, and playback bypasses any
/// client library entirely — libmpv opens the `https://` URL itself with the
/// auth header this class supplies. That keeps the parser under test without a
/// live server.
class WebDavSource implements BrowsableSource {
  WebDavSource({
    required this.config,
    required this.password,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final SourceConfig config;

  /// Read out of secure storage by the repository just before constructing
  /// this driver; never persisted alongside [config].
  final String? password;

  final Dio _dio;

  @override
  String get id => config.id;

  @override
  SourceKind get kind => SourceKind.webdav;

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(externalSubtitles: true);

  @override
  String get rootLabel => config.name;

  /// Basic auth, reused for both PROPFIND and the stream libmpv opens.
  Map<String, String> get authHeaders {
    if (!config.needsAuth || password == null) return const <String, String>{};
    final token = base64Encode(utf8.encode('${config.username}:$password'));
    return <String, String>{'Authorization': 'Basic $token'};
  }

  Uri get _base {
    final raw = config.uri.endsWith('/')
        ? config.uri.substring(0, config.uri.length - 1)
        : config.uri;
    return Uri.parse(raw);
  }

  /// Joins a source-relative path onto the base, encoding each segment.
  Uri urlFor(String path) {
    final clean = path.split('/').where((s) => s.isNotEmpty).toList();
    return _base.replace(
      pathSegments: <String>[..._base.pathSegments.where((s) => s.isNotEmpty), ...clean],
    );
  }

  @override
  Future<BrowseListing> listDirectory(String path) async {
    final url = urlFor(path);

    late final Response<String> response;
    try {
      response = await _dio.requestUri<String>(
        url,
        options: Options(
          method: 'PROPFIND',
          // Depth 1 is the directory itself plus its children; Infinity is
          // refused by most servers and would be ruinous on a big share.
          headers: <String, String>{
            ...authHeaders,
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 400,
        ),
        data: _propfindBody,
      );
    } on DioException catch (e) {
      throw MediaSourceException(_describe(e, url), cause: e);
    }

    final body = response.data;
    if (body == null || body.isEmpty) {
      throw MediaSourceException('$url returned an empty listing.');
    }

    return BrowseListing(
      path: path,
      entries: parsePropfind(body, requestPath: url.path),
    );
  }

  @override
  Future<PlayableMedia> resolve(MediaRef ref) async {
    final url = urlFor(ref.itemId);
    return PlayableMedia(
      ref: ref,
      uri: url,
      kind: kind,
      capabilities: capabilities,
      // libmpv streams this directly; there is no local proxy in the way,
      // which is what makes WebDAV direct-play.
      headers: authHeaders,
      sourceLine: '${config.name} · WebDAV · direct play',
    );
  }

  static String _describe(DioException e, Uri url) {
    final status = e.response?.statusCode;
    return switch (status) {
      401 || 403 => 'Access denied by ${url.host}. Check the username and '
          'password for "${url.host}".',
      404 => 'Not found on ${url.host}:\n${url.path}',
      405 => '${url.host} rejected PROPFIND — is this really a WebDAV share?',
      _ => 'Could not reach ${url.host}'
          '${status == null ? '' : ' (HTTP $status)'}.',
    };
  }

  static const _propfindBody = '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:">'
      '<d:prop>'
      '<d:resourcetype/>'
      '<d:getcontentlength/>'
      '<d:getlastmodified/>'
      '<d:displayname/>'
      '</d:prop>'
      '</d:propfind>';
}

/// Parses a `multistatus` body into rows.
///
/// Top-level so it can be tested against captured server responses without a
/// [Dio] or a live share. Namespace prefixes vary between servers (`d:`, `D:`,
/// none at all), so elements are matched on local name.
List<BrowseEntry> parsePropfind(String xmlBody, {required String requestPath}) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xmlBody);
  } on XmlException catch (e) {
    throw MediaSourceException('The server returned malformed XML.', cause: e);
  }

  final self = _normalise(requestPath);
  final entries = <BrowseEntry>[];

  for (final XmlElement response in _byLocalName(document.rootElement, 'response')) {
    final href = _textOf(response, 'href');
    if (href == null) continue;

    final path = _normalise(Uri.decodeFull(href));
    // Depth 1 includes the directory being listed; it is not one of its rows.
    if (path == self) continue;

    final isCollection = _byLocalName(response, 'collection').isNotEmpty;
    final name = _displayName(response, path);
    if (name.isEmpty) continue;

    final lengthText = _textOf(response, 'getcontentlength');
    final size = lengthText == null ? null : int.tryParse(lengthText.trim());
    final modified = _parseHttpDate(_textOf(response, 'getlastmodified'));

    entries.add(
      BrowseEntry(
        name: name,
        kind: isCollection ? BrowseEntryKind.folder : classifyFile(name),
        path: path,
        sizeBytes: size,
        modified: modified,
        detail: isCollection
            ? 'Folder'
            : <String>[
                if (size != null) formatBytes(size),
                if (modified != null) _shortDate(modified),
              ].join(' · '),
      ),
    );
  }

  // Folders first, then case-insensitive by name — the order a file manager
  // is expected to use, since servers return whatever order they like.
  entries.sort((a, b) {
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return entries;
}

String _displayName(XmlElement response, String path) {
  final display = _textOf(response, 'displayname')?.trim();
  if (display != null && display.isNotEmpty) return display;

  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  return segments.isEmpty ? '' : segments.last;
}

Iterable<XmlElement> _byLocalName(XmlElement root, String name) =>
    root.descendantElements.where((e) => e.localName == name);

String? _textOf(XmlElement root, String name) {
  for (final XmlElement e in root.descendantElements) {
    if (e.localName == name) return e.innerText;
  }
  return null;
}

/// Trailing slashes and percent-encoding differ between the request and the
/// response, so both sides are normalised before comparing.
String _normalise(String path) {
  var p = Uri.decodeFull(path);
  // An href may be a full URL rather than a path.
  final parsed = Uri.tryParse(p);
  if (parsed != null && parsed.hasScheme) p = parsed.path;
  while (p.endsWith('/') && p.length > 1) {
    p = p.substring(0, p.length - 1);
  }
  return p.isEmpty ? '/' : p;
}

DateTime? _parseHttpDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    // RFC 1123, e.g. "Tue, 10 Feb 2026 09:41:00 GMT".
    return HttpDate.parse(raw.trim());
  } catch (_) {
    return null;
  }
}

String _shortDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
