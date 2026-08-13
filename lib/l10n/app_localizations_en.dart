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
  String get addShareTitle => 'Add SMB, WebDAV or NFS';

  @override
  String get addShareSubtitle => 'Or scan the local network';

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
  String get unwatched => 'Unwatched';

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
  String get back10 => 'Back 10 seconds';

  @override
  String get forward30 => 'Forward 30 seconds';

  @override
  String get nothingToPlay => 'Nothing to play — pick a file from Files.';

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
