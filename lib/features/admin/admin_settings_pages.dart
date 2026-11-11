// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

/// The server settings pages, as the web dashboard groups them: Display,
/// Metadata and NFO under Libraries; Transcoding, Resume, Streaming and
/// Trickplay under Playback; DVR under Live TV; Networking under Advanced.
///
/// Each is a curated handful of one configuration object's fields — the ones
/// set by hand and safe to set from a phone. The rest stay as they are: a
/// save writes only what was changed (`AdminConfigPage`).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import 'admin_config_form.dart';
import 'admin_providers.dart';

/// Which settings page a route names.
enum AdminSettingsPage {
  display,
  metadata,
  nfo,
  transcoding,
  resume,
  streaming,
  trickplay,
  dvr,
  networking;

  static AdminSettingsPage? fromPath(String name) {
    for (final AdminSettingsPage p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// The route's page, or a sentence for a name that is not one.
class AdminSettingsRoute extends StatelessWidget {
  const AdminSettingsRoute({super.key, required this.page});

  final AdminSettingsPage page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (page) {
      AdminSettingsPage.display => AdminConfigPage(
        title: l10n.adminDisplay,
        sections: displaySections,
      ),
      AdminSettingsPage.metadata => AdminConfigPage(
        title: l10n.adminMetadataSettings,
        intro: l10n.adminMetadataIntro,
        sections: metadataSections,
      ),
      AdminSettingsPage.nfo => AdminConfigPage(
        title: l10n.adminNfo,
        intro: l10n.adminNfoIntro,
        sections: nfoSections,
      ),
      AdminSettingsPage.transcoding => AdminConfigPage(
        title: l10n.adminTranscodingSettings,
        sections: transcodingSections,
      ),
      AdminSettingsPage.resume => AdminConfigPage(
        title: l10n.adminResume,
        intro: l10n.adminResumeIntro,
        sections: resumeSections,
      ),
      AdminSettingsPage.streaming => AdminConfigPage(
        title: l10n.adminStreaming,
        sections: streamingSections,
      ),
      AdminSettingsPage.trickplay => AdminConfigPage(
        title: l10n.adminTrickplay,
        intro: l10n.adminTrickplayIntro,
        sections: trickplaySections,
      ),
      AdminSettingsPage.dvr => AdminConfigPage(
        title: l10n.adminDvr,
        sections: dvrSections,
      ),
      AdminSettingsPage.networking => AdminConfigPage(
        title: l10n.adminNetworking,
        // Ports and addresses are how this phone reaches the server; a
        // wrong one is a server the app can no longer open to undo it.
        intro: l10n.adminNetworkingIntro,
        sections: networkingSections,
      ),
    };
  }
}

ConfigPath _root(String a, [String? b]) => ConfigPath(<String>[a, ?b]);

// ------------------------------------------------------------- libraries

List<ConfigSection> displaySections(AppLocalizations l10n) => <ConfigSection>[
  ConfigSection(null, <ConfigField>[
    SwitchConfig(
      at: _root('EnableFolderView'),
      label: l10n.adminFolderView,
      help: l10n.adminFolderViewHelp,
    ),
    SwitchConfig(
      at: _root('DisplaySpecialsWithinSeasons'),
      label: l10n.adminSpecialsInSeasons,
    ),
    SwitchConfig(
      at: _root('EnableGroupingMoviesIntoCollections'),
      label: l10n.adminGroupMovies,
      help: l10n.adminGroupHelp,
    ),
    SwitchConfig(
      at: _root('EnableGroupingShowsIntoCollections'),
      label: l10n.adminGroupShows,
    ),
    SwitchConfig(
      at: _root('EnableExternalContentInSuggestions'),
      label: l10n.adminExternalSuggestions,
    ),
    SwitchConfig(
      at: const ConfigPath(<String>[
        'UseFileCreationTimeForDateAdded',
      ], key: 'metadata'),
      label: l10n.adminDateAddedFromFile,
      help: l10n.adminDateAddedFromFileHelp,
    ),
  ]),
];

List<ConfigSection> metadataSections(AppLocalizations l10n) => <ConfigSection>[
  ConfigSection(l10n.adminPreferredMetadata, <ConfigField>[
    ChoiceConfig(
      at: _root('PreferredMetadataLanguage'),
      label: l10n.adminMetadataLanguage,
      load: culturesProvider,
    ),
    ChoiceConfig(
      at: _root('MetadataCountryCode'),
      label: l10n.adminMetadataCountry,
      load: countriesProvider,
    ),
  ]),
  ConfigSection(l10n.adminChapters, <ConfigField>[
    NumberConfig(
      at: _root('DummyChapterDuration'),
      label: l10n.adminDummyChapters,
      help: l10n.adminDummyChaptersHelp,
      min: 0,
      max: 3600,
      unit: ' s',
    ),
    ChoiceConfig(
      at: _root('ChapterImageResolution'),
      label: l10n.adminChapterImageSize,
      options: <ConfigOption>[
        ConfigOption(value: 'MatchSource', label: l10n.adminMatchSource),
        for (final String p in <String>[
          '144',
          '240',
          '360',
          '480',
          '720',
          '1080',
          '1440',
          '2160',
        ])
          ConfigOption(value: 'P$p', label: '${p}p'),
      ],
    ),
  ]),
];

List<ConfigSection> nfoSections(AppLocalizations l10n) {
  const nfo = 'xbmcmetadata';
  ConfigPath at(String k) => ConfigPath(<String>[k], key: nfo);
  return <ConfigSection>[
    ConfigSection(null, <ConfigField>[
      ChoiceConfig(
        at: at('UserId'),
        label: l10n.adminNfoUser,
        help: l10n.adminNfoUserHelp,
        load: userOptionsProvider,
        allowNone: true,
        noneLabel: l10n.adminNone,
      ),
      TextConfig(
        at: at('ReleaseDateFormat'),
        label: l10n.adminNfoDateFormat,
        help: 'yyyy-MM-dd',
      ),
      SwitchConfig(
        at: at('SaveImagePathsInNfo'),
        label: l10n.adminNfoImagePaths,
      ),
      SwitchConfig(
        at: at('EnablePathSubstitution'),
        label: l10n.adminNfoPathSubstitution,
      ),
      SwitchConfig(
        at: at('EnableExtraThumbsDuplication'),
        label: l10n.adminNfoExtraThumbs,
      ),
    ]),
  ];
}

// -------------------------------------------------------------- playback

/// Values as the server spells them; labels for the ones that need one.
/// "None" is worded per language where the list is built.
const List<ConfigOption> _accelerations = <ConfigOption>[
  ConfigOption(value: 'amf', label: 'AMD AMF'),
  ConfigOption(value: 'qsv', label: 'Intel Quick Sync (QSV)'),
  ConfigOption(value: 'nvenc', label: 'NVIDIA NVENC'),
  ConfigOption(value: 'vaapi', label: 'Video Acceleration API (VA-API)'),
  ConfigOption(value: 'videotoolbox', label: 'Apple VideoToolBox'),
  ConfigOption(value: 'v4l2m2m', label: 'Video4Linux2 (V4L2)'),
  ConfigOption(value: 'rkmpp', label: 'Rockchip MPP (RKMPP)'),
];

const List<ConfigOption> _codecs = <ConfigOption>[
  ConfigOption(value: 'h264', label: 'H.264'),
  ConfigOption(value: 'hevc', label: 'HEVC'),
  ConfigOption(value: 'mpeg2video', label: 'MPEG-2'),
  ConfigOption(value: 'vc1', label: 'VC-1'),
  ConfigOption(value: 'vp8', label: 'VP8'),
  ConfigOption(value: 'vp9', label: 'VP9'),
  ConfigOption(value: 'av1', label: 'AV1'),
];

List<ConfigSection> transcodingSections(AppLocalizations l10n) {
  const enc = 'encoding';
  ConfigPath at(String k) => ConfigPath(<String>[k], key: enc);
  return <ConfigSection>[
    ConfigSection(l10n.adminHardware, <ConfigField>[
      ChoiceConfig(
        at: at('HardwareAccelerationType'),
        label: l10n.adminHwAcceleration,
        options: <ConfigOption>[
          ConfigOption(value: 'none', label: l10n.adminNone),
          ..._accelerations,
        ],
      ),
      MultiChoiceConfig(
        at: at('HardwareDecodingCodecs'),
        label: l10n.adminHwDecoding,
        help: l10n.adminHwDecodingHelp,
        options: _codecs,
      ),
      SwitchConfig(
        at: at('EnableDecodingColorDepth10Hevc'),
        label: l10n.adminHevc10,
      ),
      SwitchConfig(
        at: at('EnableDecodingColorDepth10Vp9'),
        label: l10n.adminVp910,
      ),
      SwitchConfig(
        at: at('EnableHardwareEncoding'),
        label: l10n.adminHwEncoding,
      ),
    ]),
    ConfigSection(l10n.adminEncoding, <ConfigField>[
      SwitchConfig(at: at('AllowHevcEncoding'), label: l10n.adminAllowHevc),
      SwitchConfig(at: at('AllowAv1Encoding'), label: l10n.adminAllowAv1),
      SwitchConfig(
        at: at('EnableTonemapping'),
        label: l10n.adminTonemapping,
        help: l10n.adminTonemappingHelp,
      ),
      ChoiceConfig(
        at: at('EncoderPreset'),
        label: l10n.adminEncoderPreset,
        help: l10n.adminEncoderPresetHelp,
        options: <ConfigOption>[
          ConfigOption(value: 'auto', label: l10n.adminAuto),
          for (final String p in <String>[
            'veryslow',
            'slower',
            'slow',
            'medium',
            'fast',
            'faster',
            'veryfast',
            'superfast',
            'ultrafast',
          ])
            ConfigOption(value: p, label: p),
        ],
      ),
      NumberConfig(
        at: at('H264Crf'),
        label: l10n.adminH264Crf,
        help: l10n.adminCrfHelp,
        min: 0,
        max: 51,
      ),
      NumberConfig(
        at: at('H265Crf'),
        label: l10n.adminH265Crf,
        min: 0,
        max: 51,
      ),
      NumberConfig(
        at: at('EncodingThreadCount'),
        label: l10n.adminThreads,
        help: l10n.adminThreadsHelp,
        min: -1,
        max: 256,
      ),
    ]),
    ConfigSection(l10n.adminTranscodeFiles, <ConfigField>[
      FolderConfig(
        at: at('TranscodingTempPath'),
        label: l10n.adminTranscodePath,
      ),
      SwitchConfig(
        at: at('EnableThrottling'),
        label: l10n.adminThrottle,
        help: l10n.adminThrottleHelp,
      ),
      SwitchConfig(
        at: at('EnableSegmentDeletion'),
        label: l10n.adminDeleteSegments,
        help: l10n.adminDeleteSegmentsHelp,
      ),
    ]),
  ];
}

List<ConfigSection> resumeSections(AppLocalizations l10n) => <ConfigSection>[
  ConfigSection(l10n.adminVideo, <ConfigField>[
    NumberConfig(
      at: _root('MinResumePct'),
      label: l10n.adminMinResumePct,
      help: l10n.adminMinResumePctHelp,
      min: 0,
      max: 100,
      unit: '%',
    ),
    NumberConfig(
      at: _root('MaxResumePct'),
      label: l10n.adminMaxResumePct,
      help: l10n.adminMaxResumePctHelp,
      min: 1,
      max: 100,
      unit: '%',
    ),
    NumberConfig(
      at: _root('MinResumeDurationSeconds'),
      label: l10n.adminMinResumeDuration,
      help: l10n.adminMinResumeDurationHelp,
      min: 0,
      unit: ' s',
    ),
  ]),
  ConfigSection(l10n.adminAudiobooks, <ConfigField>[
    NumberConfig(
      at: _root('MinAudiobookResume'),
      label: l10n.adminMinAudiobookResume,
      min: 0,
      unit: ' min',
    ),
    NumberConfig(
      at: _root('MaxAudiobookResume'),
      label: l10n.adminMaxAudiobookResume,
      min: 0,
      unit: ' min',
    ),
  ]),
];

List<ConfigSection> streamingSections(AppLocalizations l10n) => <ConfigSection>[
  ConfigSection(null, <ConfigField>[
    ChoiceConfig(
      at: _root('RemoteClientBitrateLimit'),
      label: l10n.adminRemoteBitrate,
      help: l10n.adminRemoteBitrateHelp,
      numeric: true,
      options: <ConfigOption>[
        ConfigOption(value: '0', label: l10n.adminNoLimit),
        for (final int mbps in <int>[1, 2, 4, 8, 10, 15, 20, 40, 60, 80, 120])
          ConfigOption(
            value: '${mbps * 1000000}',
            label: l10n.adminMbps('$mbps'),
          ),
      ],
    ),
  ]),
];

List<ConfigSection> trickplaySections(AppLocalizations l10n) {
  ConfigPath at(String k) => _root('TrickplayOptions', k);
  return <ConfigSection>[
    ConfigSection(l10n.adminHardware, <ConfigField>[
      SwitchConfig(
        at: at('EnableHwAcceleration'),
        label: l10n.adminHwDecodingShort,
      ),
      SwitchConfig(
        at: at('EnableHwEncoding'),
        label: l10n.adminHwEncodingShort,
      ),
      SwitchConfig(
        at: at('EnableKeyFrameOnlyExtraction'),
        label: l10n.adminKeyframesOnly,
        help: l10n.adminKeyframesOnlyHelp,
      ),
    ]),
    ConfigSection(l10n.adminTrickplayImages, <ConfigField>[
      ChoiceConfig(
        at: at('ScanBehavior'),
        label: l10n.adminScanBehavior,
        options: <ConfigOption>[
          ConfigOption(value: 'NonBlocking', label: l10n.adminNonBlocking),
          ConfigOption(value: 'Blocking', label: l10n.adminBlocking),
        ],
      ),
      ChoiceConfig(
        at: at('ProcessPriority'),
        label: l10n.adminProcessPriority,
        options: <ConfigOption>[
          for (final String p in <String>[
            'Idle',
            'BelowNormal',
            'Normal',
            'AboveNormal',
            'High',
          ])
            ConfigOption(value: p, label: p),
        ],
      ),
      NumberConfig(
        at: at('Interval'),
        label: l10n.adminTrickplayInterval,
        help: l10n.adminTrickplayIntervalHelp,
        min: 1000,
        max: 600000,
        unit: ' ms',
      ),
      TextConfig(
        at: at('WidthResolutions'),
        label: l10n.adminTrickplayWidths,
        help: l10n.adminTrickplayWidthsHelp,
        intList: true,
      ),
      NumberConfig(
        at: at('TileWidth'),
        label: l10n.adminTileWidth,
        min: 1,
        max: 50,
      ),
      NumberConfig(
        at: at('TileHeight'),
        label: l10n.adminTileHeight,
        min: 1,
        max: 50,
      ),
      NumberConfig(
        at: at('JpegQuality'),
        label: l10n.adminJpegQuality,
        min: 1,
        max: 100,
      ),
      NumberConfig(
        at: at('ProcessThreads'),
        label: l10n.adminThreads,
        min: 0,
        max: 64,
      ),
    ]),
  ];
}

// --------------------------------------------------------- live tv, network

List<ConfigSection> dvrSections(AppLocalizations l10n) {
  const live = 'livetv';
  ConfigPath at(String k) => ConfigPath(<String>[k], key: live);
  return <ConfigSection>[
    ConfigSection(l10n.adminRecordings, <ConfigField>[
      FolderConfig(at: at('RecordingPath'), label: l10n.adminRecordingPath),
      FolderConfig(
        at: at('MovieRecordingPath'),
        label: l10n.adminMovieRecordingPath,
      ),
      FolderConfig(
        at: at('SeriesRecordingPath'),
        label: l10n.adminSeriesRecordingPath,
      ),
      SwitchConfig(
        at: at('EnableRecordingSubfolders'),
        label: l10n.adminRecordingSubfolders,
      ),
      NumberConfig(
        at: at('PrePaddingSeconds'),
        label: l10n.adminPrePadding,
        min: 0,
        unit: ' s',
      ),
      NumberConfig(
        at: at('PostPaddingSeconds'),
        label: l10n.adminPostPadding,
        min: 0,
        unit: ' s',
      ),
      SwitchConfig(
        at: at('SaveRecordingNFO'),
        label: l10n.adminSaveRecordingNfo,
      ),
      SwitchConfig(
        at: at('SaveRecordingImages'),
        label: l10n.adminSaveRecordingImages,
      ),
    ]),
    ConfigSection(l10n.adminGuide, <ConfigField>[
      ChoiceConfig(
        at: at('GuideDays'),
        label: l10n.adminGuideDays,
        numeric: true,
        allowNone: true,
        noneLabel: l10n.adminAuto,
        options: <ConfigOption>[
          for (var d = 1; d <= 14; d++) ConfigOption(value: '$d', label: '$d'),
        ],
      ),
    ]),
    ConfigSection(l10n.adminPostProcessing, <ConfigField>[
      TextConfig(
        at: at('RecordingPostProcessor'),
        label: l10n.adminPostProcessor,
      ),
      TextConfig(
        at: at('RecordingPostProcessorArguments'),
        label: l10n.adminPostProcessorArgs,
        help: '"{path}"',
      ),
    ]),
  ];
}

List<ConfigSection> networkingSections(AppLocalizations l10n) {
  const net = 'network';
  ConfigPath at(String k) => ConfigPath(<String>[k], key: net);
  return <ConfigSection>[
    ConfigSection(l10n.adminServerAccess, <ConfigField>[
      SwitchConfig(
        at: at('EnableRemoteAccess'),
        label: l10n.adminRemoteAccess,
        help: l10n.adminRemoteAccessHelp,
      ),
      TextConfig(
        at: at('LocalNetworkSubnets'),
        label: l10n.adminLanNetworks,
        help: l10n.adminLanNetworksHelp,
        stringList: true,
      ),
      TextConfig(
        at: at('KnownProxies'),
        label: l10n.adminKnownProxies,
        help: l10n.adminListHelp,
        stringList: true,
      ),
      TextConfig(
        at: at('PublishedServerUriBySubnet'),
        label: l10n.adminPublishedUris,
        help: l10n.adminPublishedUrisHelp,
        stringList: true,
      ),
      SwitchConfig(at: at('AutoDiscovery'), label: l10n.adminAutoDiscovery),
    ]),
    ConfigSection(l10n.adminPorts, <ConfigField>[
      NumberConfig(
        at: at('InternalHttpPort'),
        label: l10n.adminHttpPort,
        min: 1,
        max: 65535,
      ),
      NumberConfig(
        at: at('InternalHttpsPort'),
        label: l10n.adminHttpsPort,
        min: 1,
        max: 65535,
      ),
      NumberConfig(
        at: at('PublicHttpPort'),
        label: l10n.adminPublicHttpPort,
        min: 1,
        max: 65535,
      ),
      NumberConfig(
        at: at('PublicHttpsPort'),
        label: l10n.adminPublicHttpsPort,
        min: 1,
        max: 65535,
      ),
      SwitchConfig(at: at('EnableHttps'), label: l10n.adminEnableHttps),
      SwitchConfig(
        at: at('RequireHttps'),
        label: l10n.adminRequireHttps,
        help: l10n.adminRequireHttpsHelp,
      ),
    ]),
    ConfigSection(l10n.adminIpFilter, <ConfigField>[
      TextConfig(
        at: at('RemoteIPFilter'),
        label: l10n.adminRemoteIpFilter,
        help: l10n.adminListHelp,
        stringList: true,
      ),
      SwitchConfig(
        at: at('IsRemoteIPFilterBlacklist'),
        label: l10n.adminIpFilterBlocklist,
        help: l10n.adminIpFilterBlocklistHelp,
      ),
      SwitchConfig(at: at('EnableIPv4'), label: 'IPv4'),
      SwitchConfig(at: at('EnableIPv6'), label: 'IPv6'),
    ]),
  ];
}
