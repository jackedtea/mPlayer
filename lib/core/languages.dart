// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// Track languages, and the one rule that makes them comparable.
///
/// A container labels its tracks however the muxer felt like it: `vie`, `vi`,
/// `vietnamese`, `vi-VN`, sometimes with the region attached and sometimes in
/// the wrong case. Matching on the raw string therefore fails constantly, so
/// everything here reduces a label to a canonical two-letter code first.
library;

/// A language the user can pick as their own.
///
/// Deliberately a short list of the languages media is actually shipped in,
/// each named in itself — a user looking for "Tiếng Việt" should not have to
/// recognise "Vietnamese".
class LanguageOption {
  const LanguageOption(this.code, this.label);

  /// The canonical two-letter code, which is what gets persisted.
  final String code;

  final String label;
}

const languageOptions = <LanguageOption>[
  LanguageOption('en', 'English'),
  LanguageOption('vi', 'Tiếng Việt'),
  LanguageOption('ja', '日本語'),
  LanguageOption('ko', '한국어'),
  LanguageOption('zh', '中文'),
  LanguageOption('th', 'ไทย'),
  LanguageOption('id', 'Bahasa Indonesia'),
  LanguageOption('fr', 'Français'),
  LanguageOption('de', 'Deutsch'),
  LanguageOption('es', 'Español'),
  LanguageOption('pt', 'Português'),
  LanguageOption('ru', 'Русский'),
];

/// Three-letter codes and English names that reduce to a two-letter code.
///
/// Both ISO 639-2 forms are here on purpose: a container may carry either the
/// bibliographic (`ger`, `fre`, `chi`) or the terminological (`deu`, `fra`,
/// `zho`) spelling, and which one appears says nothing about the file.
const _aliases = <String, String>{
  'eng': 'en', 'english': 'en',
  'vie': 'vi', 'vietnamese': 'vi', 'tiếng việt': 'vi',
  'jpn': 'ja', 'japanese': 'ja',
  'kor': 'ko', 'korean': 'ko',
  'zho': 'zh', 'chi': 'zh', 'cmn': 'zh', 'chinese': 'zh',
  'yue': 'zh', 'cantonese': 'zh',
  'tha': 'th', 'thai': 'th',
  'ind': 'id', 'indonesian': 'id',
  'fra': 'fr', 'fre': 'fr', 'french': 'fr',
  'deu': 'de', 'ger': 'de', 'german': 'de',
  'spa': 'es', 'esp': 'es', 'spanish': 'es',
  'por': 'pt', 'portuguese': 'pt',
  'rus': 'ru', 'russian': 'ru',
  // Common on film and series tracks, though not offered as a preference.
  'ita': 'it', 'italian': 'it',
  'hin': 'hi', 'hindi': 'hi',
  'ara': 'ar', 'arabic': 'ar',
  'tur': 'tr', 'turkish': 'tr',
  'pol': 'pl', 'polish': 'pl',
  'nld': 'nl', 'dut': 'nl', 'dutch': 'nl',
  'swe': 'sv', 'swedish': 'sv',
  'nor': 'no', 'nob': 'no', 'norwegian': 'no',
  'dan': 'da', 'danish': 'da',
  'fin': 'fi', 'finnish': 'fi',
  'ces': 'cs', 'cze': 'cs', 'czech': 'cs',
  'ell': 'el', 'gre': 'el', 'greek': 'el',
  'heb': 'he', 'hebrew': 'he',
  'hun': 'hu', 'hungarian': 'hu',
  'ukr': 'uk', 'ukrainian': 'uk',
  'msa': 'ms', 'may': 'ms', 'malay': 'ms',
  'fil': 'tl', 'tgl': 'tl', 'filipino': 'tl', 'tagalog': 'tl',
  'ron': 'ro', 'rum': 'ro', 'romanian': 'ro',
};

/// Names for the languages a track is likely to be in, beyond the ones
/// offered as a preference — each in its own language, as the picker names
/// them, so a viewer looks for their own language under the name they know.
const _trackLanguageNames = <String, String>{
  'it': 'Italiano',
  'hi': 'हिन्दी',
  'ar': 'العربية',
  'tr': 'Türkçe',
  'pl': 'Polski',
  'nl': 'Nederlands',
  'sv': 'Svenska',
  'no': 'Norsk',
  'da': 'Dansk',
  'fi': 'Suomi',
  'cs': 'Čeština',
  'el': 'Ελληνικά',
  'he': 'עברית',
  'hu': 'Magyar',
  'uk': 'Українська',
  'ms': 'Bahasa Melayu',
  'tl': 'Filipino',
  'ro': 'Română',
};

/// What a track's language is called, or null when the track does not say.
///
/// The name from [languageOptions] or the wider list above; a code neither
/// knows comes back upper-cased, which still tells two tracks apart.
String? trackLanguageName(String? raw) {
  final code = canonicalLanguage(raw);
  if (code == null) return null;
  for (final LanguageOption option in languageOptions) {
    if (option.code == code) return option.label;
  }
  return _trackLanguageNames[code] ?? code.toUpperCase();
}

/// The short tag for a track's language — "EN", "VI" — or null.
String? trackLanguageTag(String? raw) => canonicalLanguage(raw)?.toUpperCase();

/// Reduces a track's language label to a two-letter code, or null when it
/// carries no usable one.
///
/// `und` is mpv's marker for an unlabelled track and is treated as unknown —
/// guessing that it is the user's language would switch subtitles off on
/// exactly the foreign films they are wanted for.
String? canonicalLanguage(String? raw) {
  final trimmed = raw?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) return null;

  // "pt-BR", "zh_Hans", "en (SDH)" — the tag before the separator is the
  // language; the rest is region, script or a muxer's note.
  final head = trimmed.split(RegExp(r'[-_ (\[]')).first;
  if (head.isEmpty) return null;

  if (head == 'und' || head == 'unknown' || head == 'mis' || head == 'zxx') {
    return null;
  }

  final alias = _aliases[head] ?? _aliases[trimmed];
  if (alias != null) return alias;

  // An unlisted code is returned as it stands: a two-letter one is already
  // canonical, and a longer one that is not in the table can still match
  // another track carrying the same spelling.
  return head;
}

/// Whether a track's language is the one the user reads in.
///
/// Null on either side is "do not know", which never matches: acting on a
/// guess here means either hiding subtitles someone needs or showing ones
/// they do not.
bool languageMatches(String? trackLanguage, String? preferred) {
  final a = canonicalLanguage(trackLanguage);
  final b = canonicalLanguage(preferred);
  if (a == null || b == null) return false;
  return a == b;
}

/// The name to show for a stored code, falling back to the code itself so a
/// value from a newer build still reads as something.
String languageLabel(String? code) {
  if (code == null) return 'No preference';
  for (final option in languageOptions) {
    if (option.code == code) return option.label;
  }
  return code.toUpperCase();
}
