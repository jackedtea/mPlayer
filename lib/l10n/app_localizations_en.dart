// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'mPlayer';

  @override
  String get navStorage => 'Files';

  @override
  String get navServer => 'Servers';

  @override
  String get navSearch => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionTest => 'Test';

  @override
  String get actionConnect => 'Connect';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionBack => 'Back';

  @override
  String get actionMore => 'More';

  @override
  String get actionSort => 'Sort';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionRemove => 'Remove';

  @override
  String get viewList => 'List view';

  @override
  String get viewGrid => 'Grid view';

  @override
  String notImplemented(String feature) {
    return '$feature — not implemented yet';
  }

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get thisDevice => 'This device';

  @override
  String get network => 'Network';

  @override
  String get openFileOrFolder => 'Open a file or folder';

  @override
  String get addShareTitle => 'Add SMB or WebDAV';

  @override
  String get addShareSubtitle => 'A share on your network';

  @override
  String driverUnavailable(String kind) {
    return '$kind — driver not available yet';
  }

  @override
  String get shareOptions => 'Share options';

  @override
  String get removeShare => 'Remove share';

  @override
  String get removeShareSubtitle => 'Its saved password is deleted too';

  @override
  String get addShareHeading => 'Add a share';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get anonymousHint => 'Leave empty for an anonymous share';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String noDriverNotice(String kind) {
    return '$kind has no driver yet. The share will be saved and listed, but cannot be browsed until it lands.';
  }

  @override
  String connectionOk(int folders, int files) {
    return 'Connected — $folders folders, $files files';
  }

  @override
  String folderCounts(int folders, int files) {
    return '$folders folders · $files files';
  }

  @override
  String get reading => 'Reading…';

  @override
  String get directPlay => 'Direct play';

  @override
  String get folder => 'Folder';

  @override
  String get emptyFolder => 'This folder is empty';

  @override
  String get couldNotReadFolder => 'Could not read this folder.';

  @override
  String notAVideo(String name) {
    return '$name is not a video file';
  }

  @override
  String get noServerTitle => 'No media server yet';

  @override
  String get noServerBody =>
      'Everything on this device and your network shares already works without one. Add a Jellyfin server to sync watch state, metadata and remote access.';

  @override
  String get addJellyfinServer => 'Add Jellyfin server';

  @override
  String get scanNetwork => 'Scan this network';

  @override
  String get otherServersNotice =>
      'Emby and Plex servers can be added here too — the tab is not Jellyfin-only.';

  @override
  String get previewConnectedServer => 'Preview a connected server';

  @override
  String get addServerHeading => 'Add a server';

  @override
  String get serverAddress => 'Server address';

  @override
  String get detectHint => 'Enter an address to detect the server';

  @override
  String get detectPending => 'Detection runs once the Jellyfin client lands';

  @override
  String get quickConnect => 'Quick connect instead';

  @override
  String get quickConnectSubtitle => 'Approve from another signed-in device';

  @override
  String get nextUp => 'Next up';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get libraries => 'Libraries';

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String get unwatched => 'new';

  @override
  String unwatchedCount(int count) {
    return '$count unwatched';
  }

  @override
  String get genre => 'Genre';

  @override
  String get filters => 'Filters';

  @override
  String get cast => 'Cast';

  @override
  String get more => 'More';

  @override
  String get less => 'Less';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get download => 'Download';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get searchEverything => 'Search everything';

  @override
  String get voiceSearch => 'Voice search';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get whereToLook => 'Where to look';

  @override
  String get allSources => 'All sources';

  @override
  String get backToSources => 'Back to sources';

  @override
  String showMoreFrom(int count, String source) {
    return 'Show $count more from $source';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String get nothingDownloaded => 'Nothing downloaded';

  @override
  String get downloadsBody =>
      'Downloads are queued on Wi-Fi by default and expire per the server\'s policy.';

  @override
  String get pauseDownload => 'Pause';

  @override
  String get cancelDownload => 'Cancel';

  @override
  String get availableOffline => 'Available offline';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSub => 'Theme, accent colour, density';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralSub => 'Language, startup tab, cache';

  @override
  String get settingsPlayer => 'Player';

  @override
  String get settingsPlayerSub => 'Decoding, gestures, streaming quality';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAudioSub => 'Passthrough, track language, boost';

  @override
  String get settingsSubtitle => 'Subtitle';

  @override
  String get settingsSubtitleSub => 'Style, language order, sync offset';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSub => 'Version, licences, diagnostics';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get accent => 'Accent';

  @override
  String get dynamicColour => 'Material You dynamic colour';

  @override
  String get dynamicColourSub => 'Follow the system wallpaper palette';

  @override
  String get pureBlack => 'Pure black in dark mode';

  @override
  String get pureBlackSub => 'Saves power on OLED screens';

  @override
  String get layout => 'Layout';

  @override
  String get defaultLibraryView => 'Default library view';

  @override
  String get density => 'Density';

  @override
  String get playback => 'Playback';

  @override
  String get hardwareDecoding => 'Hardware decoding';

  @override
  String get hardwareDecodingValue => 'Auto (safe)';

  @override
  String get hardwareDecodingSub =>
      'Falls back to software when a codec is unsupported';

  @override
  String get resumeBehaviour => 'Resume behaviour';

  @override
  String get skipBack => 'Skip back';

  @override
  String get skipForward => 'Skip forward';

  @override
  String get autoPlayNext => 'Auto-play next episode';

  @override
  String get autoSkipIntro => 'Auto skip intro';

  @override
  String get autoSkipIntroSub => 'Only where the server marks an intro chapter';

  @override
  String get screenAndGestures => 'Screen & gestures';

  @override
  String get rotation => 'Rotation';

  @override
  String get rotationFollowVideo => 'Follow video';

  @override
  String get swipeGestures => 'Swipe gestures';

  @override
  String get swipeGesturesSub => 'Brightness on the left, volume on the right';

  @override
  String get backgroundPip => 'Background & picture-in-picture';

  @override
  String get streamingQuality => 'Streaming quality';

  @override
  String get onWifi => 'On Wi-Fi';

  @override
  String get onCellular => 'On cellular';

  @override
  String get original => 'Original';

  @override
  String megabitsPerSecond(int value) {
    return '$value Mbps';
  }

  @override
  String get style => 'Style';

  @override
  String get font => 'Font';

  @override
  String get textSize => 'Text size';

  @override
  String get backgroundOpacity => 'Background opacity';

  @override
  String get behaviour => 'Behaviour';

  @override
  String get preferredLanguages => 'Preferred languages';

  @override
  String get burnInWhenTranscoding => 'Burn in when transcoding';

  @override
  String get burnInSub => 'Image-based subtitles only';

  @override
  String get syncOffset => 'Sync offset';

  @override
  String get subtitlePreview => 'The tide turns at midnight.';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String versionAndBuild(String version, String build) {
    return 'Version $version · build $build';
  }

  @override
  String get upToDate => 'Up to date';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get releaseNotes => 'Release notes';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get openSourceLicences => 'Open-source licences';

  @override
  String get privacy => 'Privacy';

  @override
  String get sourceCode => 'Source code';

  @override
  String get thisDeviceInfo => 'This device';

  @override
  String get notAffiliated =>
      'mPlayer is not affiliated with, endorsed by, or sponsored by the Jellyfin, Emby or Plex projects.';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get audio => 'Audio';

  @override
  String get quality => 'Quality';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get chapters => 'Chapters';

  @override
  String get noChapters => 'This file has no chapters';

  @override
  String get off => 'Off';

  @override
  String get auto => 'Auto';

  @override
  String get normal => 'Normal';

  @override
  String get defaultLabel => 'Default';

  @override
  String get skipIntro => 'Skip intro';

  @override
  String get lockPlayer => 'Lock player';

  @override
  String get screenLocked => 'Screen locked';

  @override
  String get unlockHint => 'Tap the lock twice to unlock';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get pictureInPicture => 'Picture in picture';

  @override
  String get castTo => 'Cast';

  @override
  String get aspectRatio => 'Aspect ratio';

  @override
  String get aspectFit => 'Fit';

  @override
  String get aspectFill => 'Fill';

  @override
  String get aspectStretch => 'Stretch';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String minutes(int count) {
    return '$count min';
  }

  @override
  String get statsForNerds => 'Stats for nerds';

  @override
  String get playerSettings => 'Player settings';

  @override
  String get on => 'On';

  @override
  String back10(int seconds) {
    return 'Back $seconds seconds';
  }

  @override
  String forward30(int seconds) {
    return 'Forward $seconds seconds';
  }

  @override
  String get nothingToPlay => 'Nothing to play — pick a file from Files.';

  @override
  String get previousFile => 'Previous';

  @override
  String get nextFile => 'Next';

  @override
  String get loading => 'Loading';

  @override
  String aspectRatioValue(String mode) {
    return 'Aspect ratio: $mode';
  }

  @override
  String rotationValue(String mode) {
    return 'Rotation: $mode';
  }

  @override
  String subtitlesValue(String track) {
    return 'Subtitles: $track';
  }

  @override
  String audioValue(String track) {
    return 'Audio: $track';
  }

  @override
  String speedValue(String speed) {
    return 'Speed: $speed×';
  }

  @override
  String get audioDelay => 'Audio delay';

  @override
  String get openSubtitleFile => 'Open subtitle file…';

  @override
  String get playOn => 'Play on';

  @override
  String get searchAgain => 'Search again';

  @override
  String get noDevicesFound =>
      'No devices found. Check that the television is on and on the same network.';

  @override
  String get stopCasting => 'Stop casting';

  @override
  String playingOn(String device) {
    return 'Playing on $device';
  }

  @override
  String get couldNotCast => 'Could not cast to that device.';

  @override
  String get folders => 'Folders';

  @override
  String get grantedFolder => 'Granted folder';

  @override
  String get removeFolder => 'Remove folder';

  @override
  String get addFolder => 'Add a folder';

  @override
  String get addFolderSubtitle => 'For videos the media index does not list';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get editShare => 'Edit share';

  @override
  String get editShareSubtitle => 'Change its name, address or credentials';

  @override
  String get hardwareDecodingFallback =>
      'Falls back to software when a codec is unsupported';

  @override
  String get audioDelaySub => 'Shifts the sound against the picture';

  @override
  String get autoPlayNextSub => 'Continues with the next video in the folder';

  @override
  String get pictureInPictureSub =>
      'Shrink into a floating window when you leave the app';

  @override
  String get backgroundAudio => 'Play audio in background';

  @override
  String get backgroundAudioSub =>
      'Keeps playing with the screen off, with a notification';

  @override
  String get followVideo => 'Follow video';

  @override
  String get needsTranscodingServer => 'Needs a server that can transcode';

  @override
  String get noPreference => 'No preference';

  @override
  String get noPreferenceSub => 'Leave the tracks the file chose';

  @override
  String get preferredLanguage => 'Preferred language';

  @override
  String get preferredLanguageSub =>
      'The language you would rather hear and read';

  @override
  String get smartSubtitles => 'Smart subtitles';

  @override
  String get smartSubtitlesSub =>
      'Subtitles only when the audio is in another language';

  @override
  String get imageBasedOnly => 'Image-based subtitles only';

  @override
  String get syncOffsetSub => 'Positive delays the subtitles';

  @override
  String get subtitlePreviewLine => 'The tide turns at midnight.';

  @override
  String get grid => 'Grid';

  @override
  String get comfortable => 'Comfortable';

  @override
  String get audioOutput => 'Output';

  @override
  String get passthrough => 'Bitstream passthrough';

  @override
  String get passthroughSub =>
      'Send AC3, DTS, E-AC3 and TrueHD to the amplifier undecoded';

  @override
  String get passthroughNote =>
      'Turn this on only if a receiver or soundbar is decoding for you. Without one, passthrough plays silence.';

  @override
  String get volumeBoost => 'Volume boost';

  @override
  String get volumeBoostNote =>
      'The ceiling for the volume gesture. Above 100% the sound is amplified, which rescues a quiet film and can clip a loud one.';

  @override
  String get gapless => 'Gapless playback';

  @override
  String get gaplessSub => 'How hard to try to run one file into the next';

  @override
  String get gaplessOff => 'Off';

  @override
  String get gaplessOffSub => 'Always reinitialise between files';

  @override
  String get gaplessAutomatic => 'Automatic';

  @override
  String get gaplessAutomaticSub => 'Gapless when the next file matches';

  @override
  String get gaplessAlways => 'Always';

  @override
  String get gaplessAlwaysSub => 'Gapless even if it means resampling';

  @override
  String get tracks => 'Tracks';

  @override
  String get sharedWithSubtitles => 'Shared with Subtitle settings';

  @override
  String get checkForUpdatesSub =>
      'Asks GitHub once. Nothing about you or the device is sent';

  @override
  String get diagnosticsSub =>
      'Build, device and the player log, for a bug report';

  @override
  String get privacySub => 'What leaves this device, and what does not';

  @override
  String get checking => 'Checking…';

  @override
  String updateAvailable(String version) {
    return 'Version $version is out';
  }

  @override
  String get couldNotCheck => 'Could not check';

  @override
  String couldNotOpen(String url) {
    return 'Could not open $url';
  }

  @override
  String get build => 'Build';

  @override
  String get version => 'Version';

  @override
  String get applicationId => 'Application id';

  @override
  String get platform => 'Platform';

  @override
  String get operatingSystem => 'Operating system';

  @override
  String get locale => 'Locale';

  @override
  String get screen => 'Screen';

  @override
  String get playerLog => 'Player log';

  @override
  String get copyEverything => 'Copy everything';

  @override
  String get diagnosticsCopied => 'Diagnostics copied';

  @override
  String get logEmpty =>
      'Nothing yet. The log fills while a file is playing, and is kept only for the current session.';

  @override
  String get privacyNoTelemetry =>
      'No analytics, no telemetry, no crash reporting';

  @override
  String get privacyNoTelemetryBody =>
      'There is no third-party SDK collecting anything. mPlayer contacts the servers and shares you configure, and nothing else.';

  @override
  String get privacyLocal => 'Your library stays on your device';

  @override
  String get privacyLocalBody =>
      'What you watch, where you got to and the stills on the Continue watching shelf are stored locally. None of it leaves the device.';

  @override
  String get privacyKeychain => 'Passwords live in the system keychain';

  @override
  String get privacyKeychainBody =>
      'Share and server credentials go to the platform secure storage, never into ordinary preferences alongside the rest of the settings.';

  @override
  String get privacyUpdates => 'Update checks are manual';

  @override
  String get privacyUpdatesBody =>
      'Nothing is checked on launch. Pressing \"Check for updates\" makes one anonymous request to the GitHub releases API — no identifier is sent with it.';

  @override
  String get privacyCasting => 'Casting opens a server on your network';

  @override
  String get privacyCastingBody =>
      'While a cast is running, the file being played is served over the local network so the television can fetch it. That server stops when the cast does.';

  @override
  String get privacyFooter =>
      'mPlayer is free software under the GPL-3.0-or-later. You can read the source and check every claim on this page for yourself.';

  @override
  String get noChaptersInFile => 'This file has no chapters';

  @override
  String get locked => 'Locked';

  @override
  String milliseconds(int count) {
    return '$count ms';
  }

  @override
  String seconds(int count) {
    return '$count seconds';
  }

  @override
  String timeLeft(String time) {
    return '$time left';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistName => 'Name';

  @override
  String get markWatched => 'Mark as watched';

  @override
  String get markUnwatched => 'Mark as unwatched';

  @override
  String get addFavourite => 'Add to favourites';

  @override
  String get removeFavourite => 'Remove from favourites';

  @override
  String get shufflePlay => 'Shuffle play';

  @override
  String get downloadAll => 'Download all';

  @override
  String get mediaInfo => 'Media info';

  @override
  String get startOver => 'Start over';

  @override
  String get actionFailed => 'The server would not do that.';

  @override
  String get audioTrack => 'Audio';

  @override
  String get subtitleTrack => 'Subtitles';

  @override
  String get subtitlesOff => 'Off';

  @override
  String get serverDefault => 'Server default';

  @override
  String get switchServer => 'Servers';

  @override
  String get editServer => 'Edit server';

  @override
  String get addServer => 'Add server';

  @override
  String get removeServer => 'Remove server';

  @override
  String removeServerBody(Object name) {
    return '$name will be forgotten, along with its sign-in. Nothing on the server itself is deleted.';
  }

  @override
  String get qualityOriginal => 'Original';

  @override
  String get qualityOriginalDetail =>
      'Never re-encode. Best picture, and the only option that works offline of the the server\'s own CPU.';

  @override
  String get playbackQuality => 'Playback quality';

  @override
  String episodeOf(int season, int episode) {
    return 'S${season}E$episode';
  }

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get signInAgain => 'The stored sign-in still works';

  @override
  String get change => 'Change';

  @override
  String get noServersYet => 'No servers yet.';

  @override
  String get moreLikeThis => 'More like this';

  @override
  String get about => 'About';

  @override
  String get studios => 'Studio';

  @override
  String get seriesStatus => 'Status';

  @override
  String get statusContinuing => 'Continuing';

  @override
  String get statusEnded => 'Ended';

  @override
  String get gridSize => 'Grid size';

  @override
  String gridColumns(int count) {
    return '$count per row';
  }

  @override
  String get sortName => 'A–Z';

  @override
  String get sortDateAdded => 'Recently added';

  @override
  String get sortReleaseDate => 'Release date';

  @override
  String get sortDatePlayed => 'Recently played';

  @override
  String get sortRandom => 'Random';

  @override
  String resumeAt(String time) {
    return 'Resume · $time';
  }

  @override
  String get watched => 'watched';

  @override
  String seasonCount(int count) {
    return '$count seasons';
  }

  @override
  String episodeCount(int count) {
    return '$count episodes';
  }

  @override
  String seasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String get specials => 'Specials';

  @override
  String get kindMovie => 'Movie';

  @override
  String get kindSeries => 'Series';

  @override
  String get kindSeason => 'Season';

  @override
  String get kindEpisode => 'Episode';

  @override
  String get noResults => 'Nothing matched that';

  @override
  String get clearAll => 'Clear';

  @override
  String get clearContinueWatchingTitle => 'Clear Continue watching?';

  @override
  String get clearContinueWatchingBody =>
      'Every saved position is forgotten, on this device only. Nothing is deleted from your shares or your server.';

  @override
  String get continueWatchingCleared => 'Continue watching cleared';

  @override
  String get rotationAuto => 'Auto';

  @override
  String get rotationLandscape => 'Landscape';

  @override
  String get rotationPortrait => 'Portrait';

  @override
  String get connected => 'Connected';

  @override
  String get offline => 'Offline';

  @override
  String get offlineSkipped => 'Offline — will be skipped';
}
