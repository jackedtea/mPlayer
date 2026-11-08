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
  String get navSearch => 'Search';

  @override
  String get navHome => 'Home';

  @override
  String get tabBrowse => 'Browse';

  @override
  String recentlyAddedIn(String library) {
    return 'Recently added in $library';
  }

  @override
  String get customizeHome => 'Customize home';

  @override
  String get refresh => 'Refresh';

  @override
  String get customizeHomeSub =>
      'Choose which libraries show their newest items. Saved to your account on the server, so the web app shows the same.';

  @override
  String get changeServer => 'Switch server';

  @override
  String get chooseServerFirst => 'Open a server from the Home tab first.';

  @override
  String get settingsSectionApp => 'App settings';

  @override
  String get settingsSectionServer => 'Server settings';

  @override
  String get noDownloads => 'Nothing downloaded';

  @override
  String get settings => 'Settings';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionConnect => 'Connect';

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
  String driverUnavailable(String kind) {
    return '$kind — driver not available yet';
  }

  @override
  String get addShareHeading => 'Add a share';

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
  String get noServerTitle => 'No media server yet';

  @override
  String get noServerBody =>
      'mPlayer plays what a media server gives it. Add a Jellyfin server to browse your library, keep your watch state in step across devices, and reach it from anywhere.';

  @override
  String get addJellyfinServer => 'Add Jellyfin server';

  @override
  String get scanNetwork => 'Scan this network';

  @override
  String get otherServersNotice =>
      'mPlayer works with Jellyfin servers. Emby and Plex are not supported.';

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
  String get favourites => 'Favorites';

  @override
  String get seeAll => 'See all';

  @override
  String get onThisDevice => 'Kept on this device';

  @override
  String get noFavouritesYet =>
      'Nothing starred yet. Tap the heart on a film, a show or an episode and it will be here.';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get libraries => 'Libraries';

  @override
  String get switchLibrary => 'Switch library';

  @override
  String get settingsAdmin => 'Server administration';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get settingsAdminSub => 'Sessions, tasks, users, plugins';

  @override
  String get adminTitle => 'Administration';

  @override
  String get adminNotAdmin => 'This account is not an administrator.';

  @override
  String get adminNoServer => 'Sign in to a server first.';

  @override
  String get adminServerSection => 'Server';

  @override
  String get adminSessions => 'Active sessions';

  @override
  String get adminNoSessions => 'Nobody is connected.';

  @override
  String get adminIdleSession => 'Connected, not playing';

  @override
  String get adminStopPlayback => 'Stop playback';

  @override
  String get adminSendMessage => 'Send a message';

  @override
  String adminMessageTitle(String device) {
    return 'Message to $device';
  }

  @override
  String get adminMessageHint => 'What should it say?';

  @override
  String get adminMessageSent => 'Message sent.';

  @override
  String get adminPlaybackStopped => 'Playback stopped.';

  @override
  String get adminTasks => 'Scheduled tasks';

  @override
  String get adminNoTasks => 'This server lists no tasks.';

  @override
  String get adminRunTask => 'Run now';

  @override
  String get adminStopTask => 'Stop';

  @override
  String adminTaskStarted(String name) {
    return '$name started.';
  }

  @override
  String adminTaskStopping(String name) {
    return '$name is being stopped.';
  }

  @override
  String get adminTaskNeverRun => 'Never run';

  @override
  String adminTaskLastRun(String when) {
    return 'Last run $when';
  }

  @override
  String get adminTaskLastFailed => 'Last run failed';

  @override
  String get adminScanLibraries => 'Scan all libraries';

  @override
  String get adminScanStarted => 'Library scan started.';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminNoUsers => 'No accounts on this server.';

  @override
  String get adminUserAdmin => 'Administrator';

  @override
  String get adminUserDisabled => 'Disabled';

  @override
  String get adminUserEnable => 'Enable';

  @override
  String get adminUserDisable => 'Disable';

  @override
  String adminUserEnabled(String name) {
    return '$name can sign in again.';
  }

  @override
  String adminUserNowDisabled(String name) {
    return '$name can no longer sign in.';
  }

  @override
  String get adminDevices => 'Devices';

  @override
  String get adminNoDevices => 'No devices have signed in.';

  @override
  String get adminForgetDevice => 'Forget this device';

  @override
  String get adminDeviceForgotten => 'Device forgotten.';

  @override
  String get adminActivity => 'Activity log';

  @override
  String get adminNoActivity => 'Nothing has been logged yet.';

  @override
  String get adminPlugins => 'Plugins';

  @override
  String get adminNoPlugins => 'No plugins are installed.';

  @override
  String get adminPluginEnable => 'Enable';

  @override
  String get adminPluginDisable => 'Disable';

  @override
  String get adminPluginUninstall => 'Uninstall';

  @override
  String get adminPluginRestartPending => 'Needs a restart';

  @override
  String get adminPluginBroken => 'Not working';

  @override
  String get adminPluginSuperceded => 'Superseded';

  @override
  String get adminPluginUnsupported => 'Not supported';

  @override
  String adminPluginChanged(String name) {
    return '$name updated. Some changes need a restart.';
  }

  @override
  String adminPluginRemoved(String name) {
    return '$name uninstalled.';
  }

  @override
  String adminUninstallPluginQuestion(String name) {
    return 'Uninstall $name?';
  }

  @override
  String get adminUninstallPluginBody =>
      'Its settings stay on the server, but it stops working until it is installed again.';

  @override
  String get adminRename => 'Rename server';

  @override
  String get adminRenameHint => 'Server name';

  @override
  String get adminRenamed => 'Server renamed.';

  @override
  String get renameServerLocal =>
      'Only on this device. The server and its other apps keep the name it has. Leave empty to use the server\'s.';

  @override
  String get adminRestart => 'Restart server';

  @override
  String adminRestartQuestion(String name) {
    return 'Restart $name?';
  }

  @override
  String get adminRestartBody =>
      'Everyone watching is cut off. The server comes back on its own.';

  @override
  String get adminRestarting => 'Restart requested.';

  @override
  String get adminShutdown => 'Shut down server';

  @override
  String adminShutdownQuestion(String name) {
    return 'Shut down $name?';
  }

  @override
  String get adminShutdownBody =>
      'Everyone watching is cut off, and nothing here can start it again - someone has to start it at the machine.';

  @override
  String get adminShuttingDown => 'Shutdown requested.';

  @override
  String get adminCannotRestart => 'This server cannot restart itself.';

  @override
  String get actionSend => 'Send';

  @override
  String get actionRun => 'Run';

  @override
  String get tabSuggestions => 'Suggestions';

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get tabGenres => 'Genres';

  @override
  String get noUpcoming => 'Nothing in this library is scheduled to air yet.';

  @override
  String get noGenres => 'Nothing in this library is filed under a genre.';

  @override
  String get upcomingUndated => 'Date not announced';

  @override
  String get tabCollections => 'Collections';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get noCollections => 'No collections draw on this library.';

  @override
  String get noPlaylists => 'No playlists on this server yet.';

  @override
  String get noSuggestions =>
      'Nothing to suggest yet — watch something and come back.';

  @override
  String get emptyPlaylist => 'This playlist is empty.';

  @override
  String becauseYouWatched(String title) {
    return 'Because you watched $title';
  }

  @override
  String becauseYouLike(String title) {
    return 'Because you like $title';
  }

  @override
  String directedBy(String name) {
    return 'Directed by $name';
  }

  @override
  String starring(String name) {
    return 'Starring $name';
  }

  @override
  String get suggestedForYou => 'Suggested for you';

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String itemCountAtLeast(int count) {
    return '$count+ items';
  }

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
  String get searchMovies => 'Movies';

  @override
  String get searchShows => 'Shows';

  @override
  String get searchEpisodes => 'Episodes';

  @override
  String get searchPeople => 'People';

  @override
  String get clearHistory => 'Clear all';

  @override
  String get removeFromHistory => 'Remove from history';

  @override
  String get whereToLook => 'Where to look';

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
  String get autoConnectServer => 'Open the last server on launch';

  @override
  String get autoConnectServerSub =>
      'Skip the server list and sign in to the server used most recently';

  @override
  String get density => 'Density';

  @override
  String get playback => 'Playback';

  @override
  String get decoder => 'Decoder';

  @override
  String get hardwareDecodingAuto => 'Auto (safe)';

  @override
  String get hardwareDecodingAutoSub =>
      'Hardware for the codecs mpv trusts, software for the rest';

  @override
  String get hardwareDecodingPrefer => 'Prefer hardware';

  @override
  String get hardwareDecodingPreferSub =>
      'Every codec the GPU claims. Fastest, and the one that can show a broken picture';

  @override
  String get hardwareDecodingSoftware => 'Software only';

  @override
  String get hardwareDecodingSoftwareSub =>
      'The CPU decodes everything. Heavier on the battery, but it plays what hardware gets wrong';

  @override
  String decodingNow(String decoder) {
    return 'Decoding now: $decoder';
  }

  @override
  String get decodingSoftware => 'software';

  @override
  String get hardwareDecoding => 'Hardware decoding';

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
  String get serverSegments => 'Server segments';

  @override
  String get serverSegmentsSub =>
      'What to do when a Jellyfin server marks part of an episode';

  @override
  String get segmentIntro => 'Opening titles';

  @override
  String get segmentOutro => 'Closing credits';

  @override
  String get segmentRecap => 'Recap';

  @override
  String get segmentPreview => 'Preview';

  @override
  String get segmentCommercial => 'Advert';

  @override
  String get segmentActionNothing => 'Do nothing';

  @override
  String get segmentActionAsk => 'Offer to skip';

  @override
  String get segmentActionSkip => 'Skip automatically';

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
  String get autoUpdateCheck => 'Check for updates automatically';

  @override
  String get autoUpdateCheckSub =>
      'Once a day, from GitHub. Nothing about you is sent';

  @override
  String get updateOfferBody =>
      'A newer version of mPlayer is ready to install.';

  @override
  String updateOfferBodySized(String size) {
    return 'A newer version of mPlayer is ready to install ($size MB).';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String get updateOpenPage => 'Open release page';

  @override
  String get updateDownloading => 'Downloading the update…';

  @override
  String get updateInstalling => 'Installing — mPlayer will restart.';

  @override
  String get updateInstallerOpened =>
      'The installer is open. Confirm there to finish updating.';

  @override
  String get updateNeedsPermission =>
      'Allow mPlayer to install apps in the settings page that just opened, then come back and try again.';

  @override
  String get updateNotWritable =>
      'mPlayer cannot write to the folder it is installed in, so it cannot update itself. Download the new version from the release page instead.';

  @override
  String get updateFailed =>
      'The update could not be installed. You can download it from the release page instead.';

  @override
  String get updateDownloadFailed =>
      'The download did not finish. Check the connection and try again, or download it from the release page.';

  @override
  String get updateTryAgain => 'Try again';

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
      'mPlayer is not affiliated with, endorsed by, or sponsored by the Jellyfin project.';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get audio => 'Audio';

  @override
  String get audioAndSubtitles => 'Audio & subtitles';

  @override
  String tracksValue(String audio, String subtitles) {
    return 'Audio: $audio · Subtitles: $subtitles';
  }

  @override
  String get quickBackground => 'Background';

  @override
  String get quickSpeed => 'Speed';

  @override
  String get quickScreenshot => 'Screenshot';

  @override
  String get noTracks => 'None in this file';

  @override
  String get close => 'Close';

  @override
  String get quality => 'Quality';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get chapters => 'Chapters';

  @override
  String get previousChapter => 'Previous chapter';

  @override
  String get nextChapter => 'Next chapter';

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
  String get skipCredits => 'Skip credits';

  @override
  String get skipRecap => 'Skip recap';

  @override
  String get skipPreview => 'Skip preview';

  @override
  String get skipAdvert => 'Skip advert';

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
  String get remoteTitle => 'Remote control';

  @override
  String get remoteSettingsSub =>
      'Control mPlayer on a computer or TV from this phone';

  @override
  String get remoteSearching => 'Looking for mPlayer on this network…';

  @override
  String get remoteNoDevices =>
      'No computer or TV found yet. Open mPlayer on it and make sure both are on the same network.';

  @override
  String get remoteConnectByAddress => 'Connect by address';

  @override
  String get remoteAddressLabel => 'IP address';

  @override
  String get remoteUnreachable => 'Could not reach that device.';

  @override
  String remoteConnecting(String name) {
    return 'Connecting to $name…';
  }

  @override
  String remotePinTitle(String name) {
    return 'Pair with $name';
  }

  @override
  String remotePinBody(String name) {
    return 'Enter the code shown on $name.';
  }

  @override
  String remotePinWrong(int count) {
    return 'Wrong code. $count tries left.';
  }

  @override
  String get remotePinLabel => 'Code';

  @override
  String get remoteDisconnect => 'Disconnect';

  @override
  String remoteNothingPlaying(String name) {
    return 'Nothing is playing on $name.';
  }

  @override
  String remoteNothingPlayingHint(String name) {
    return 'Pick something in the library and press Play — it will play on $name.';
  }

  @override
  String remoteControlling(String name) {
    return 'Controlling $name';
  }

  @override
  String get remoteVolume => 'Volume';

  @override
  String get remoteStop => 'Stop';

  @override
  String get remotePrevious => 'Previous';

  @override
  String remoteSentTo(String name) {
    return 'Playing on $name';
  }

  @override
  String get remotePlayHere => 'Play here';

  @override
  String remoteWrongServer(String name) {
    return '$name is signed in to a different server.';
  }

  @override
  String remoteLocked(String name) {
    return '$name is locked or signed out. Open it there first.';
  }

  @override
  String remoteVersion(String name) {
    return '$name runs a different version of mPlayer. Update both.';
  }

  @override
  String remotePlayFailed(String name) {
    return 'Could not play that on $name.';
  }

  @override
  String get remoteReceiverSetting => 'Allow phone remote';

  @override
  String get remoteReceiverSettingSub =>
      'mPlayer on a phone on this network can control playback here. A new phone has to enter the code shown on screen.';

  @override
  String get remoteForgetPhones => 'Forget paired phones';

  @override
  String get remoteForgetPhonesSub => 'Every phone will need a code again';

  @override
  String get remotePhonesForgotten => 'Paired phones forgotten.';

  @override
  String remotePairingTitle(String name) {
    return '$name wants to control mPlayer';
  }

  @override
  String get remotePairingBody => 'Enter this code on the phone';

  @override
  String remoteControlledBy(String name) {
    return 'Controlled by $name';
  }

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
  String get nextEpisode => 'Next episode';

  @override
  String get nextVideo => 'Next video';

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
  String get loop => 'Loop';

  @override
  String get loopOne => 'Repeat this video';

  @override
  String get loopAll => 'Repeat the folder';

  @override
  String qualityValue(String label) {
    return 'Quality: $label';
  }

  @override
  String screenshotSaved(String folder) {
    return 'Screenshot saved to $folder';
  }

  @override
  String get screenshotFailed => 'Could not take a screenshot of this frame';

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
      'Asks GitHub. Nothing about you or the device is sent';

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
  String get privacyUpdates => 'Update checks go to GitHub only';

  @override
  String get privacyUpdatesBody =>
      'While \"Check for updates automatically\" is on, mPlayer asks the GitHub releases API once a day whether a newer build exists — one anonymous request, with no identifier. Turn it off in Settings → General and checks happen only when you press \"Check for updates\". Updates download from the same release page.';

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
  String get addToCollection => 'Add to collection';

  @override
  String get newCollection => 'New collection';

  @override
  String addedToCollection(String name) {
    return 'Added to $name';
  }

  @override
  String get selectItems => 'Select';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get shuffleItems => 'Shuffle';

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
  String get addServerSub =>
      'Sign in to your Jellyfin server to browse and play its libraries.';

  @override
  String get addServerStepServer => 'Server';

  @override
  String get addServerStepAccount => 'Account';

  @override
  String get quickConnectShort => 'Quick Connect';

  @override
  String get quickConnectTitle => 'Quick Connect';

  @override
  String get quickConnectRowSub =>
      'Sign in another device with the code it shows';

  @override
  String get quickConnectBody =>
      'Enter the code shown on the device you want to sign in. It will be signed in as you.';

  @override
  String get quickConnectCode => 'Code';

  @override
  String get quickConnectApprove => 'Approve';

  @override
  String get quickConnectApproved => 'Device signed in.';

  @override
  String get quickConnectUnknownCode =>
      'No device is waiting with that code. Check it, or get a new one — codes expire after a few minutes.';

  @override
  String get quickConnectRefused =>
      'This server did not allow it. Quick Connect may be turned off in its settings.';

  @override
  String get quickConnectSteps =>
      'Open Settings → Quick Connect on any device that is already signed in, and enter the code there. No password is typed here.';

  @override
  String get quickConnectOff =>
      'Quick Connect is turned off on this server. An administrator can turn it on in the dashboard.';

  @override
  String get quickConnectNewCode => 'New code';

  @override
  String get quickConnectExpired =>
      'The code expired before it was approved. Get a new one and try again.';

  @override
  String get quickConnectRequesting => 'Getting a code…';

  @override
  String quickConnectWaiting(String time) {
    return 'Waiting for approval · $time left';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get pinLockTitle => 'PIN lock';

  @override
  String get pinLockOn => 'On — asked each time this server is opened here';

  @override
  String get pinLockOff => 'Off — anyone with this device can open this server';

  @override
  String get pinEnterTitle => 'PIN';

  @override
  String get pinEnterBody => 'This server is locked with a PIN on this device.';

  @override
  String get pinUnlock => 'Unlock';

  @override
  String get pinWrong => 'That PIN is not right.';

  @override
  String pinPaused(String seconds) {
    return 'Too many wrong tries. Try again in $seconds s.';
  }

  @override
  String get pinSetTitle => 'Set a PIN';

  @override
  String get pinSetBody =>
      '4 to 8 digits. It is asked for each time this server is opened on this device, and is not shared with the server.';

  @override
  String get pinNew => 'New PIN';

  @override
  String get pinConfirm => 'Confirm PIN';

  @override
  String get pinLength => 'Use 4 to 8 digits.';

  @override
  String get pinMismatch => 'The two PINs are not the same.';

  @override
  String get pinCurrent => 'Enter the current PIN';

  @override
  String get pinChange => 'Change PIN';

  @override
  String get pinRemove => 'Turn off PIN';

  @override
  String get pinSaved => 'PIN saved.';

  @override
  String get pinRemoved => 'PIN turned off.';

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
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get quickConnectHint => 'Approve from another signed-in device';

  @override
  String get connect => 'Connect';

  @override
  String get getACode => 'Get a code';

  @override
  String get enterCodeInJellyfin => 'Enter this code in Jellyfin';

  @override
  String get serverTab => 'Server';

  @override
  String get searchThisServer => 'Search this server';

  @override
  String get nothingHere => 'Nothing here.';

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
  String get viewOptions => 'View options';

  @override
  String get groupByCollection => 'Group by collection';

  @override
  String get groupByCollectionSub =>
      'One poster for each collection instead of each film in it. Not while filtering';

  @override
  String get startTab => 'Tab when opening the app';

  @override
  String get rememberLastTab => 'Remember last tab';

  @override
  String get rememberLastTabSub =>
      'Open on the tab you were on when the app closed';

  @override
  String get showOnCards => 'Show on cards';

  @override
  String get cardYear => 'Year';

  @override
  String get cardCount => 'Number of items';

  @override
  String get cardCountSub => 'Episodes in a series, films in a collection';

  @override
  String get cardStatus => 'Status';

  @override
  String get cardStatusSub => 'Whether a series is still running';

  @override
  String episodeCountShort(int count) {
    return '$count ep';
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
    return 'Continue · $time';
  }

  @override
  String get watched => 'watched';

  @override
  String get episodeNew => 'new';

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
  String get noResults => 'Nothing matched that';

  @override
  String get clearAll => 'Clear';

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

  @override
  String get sortAndFilter => 'Sort & filter';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get sortCommunityRating => 'Community rating';

  @override
  String get sortEpisodeAdded => 'Latest episode added';

  @override
  String get sortParentalRating => 'Parental rating';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterFeatures => 'Features';

  @override
  String get filterGenres => 'Genres';

  @override
  String get filterParentalRatings => 'Parental ratings';

  @override
  String get filterTags => 'Tags';

  @override
  String get filterYears => 'Years';

  @override
  String get filterPlayed => 'Watched';

  @override
  String get filterUnplayed => 'Unwatched';

  @override
  String get filterFavourite => 'Favourites';

  @override
  String get filterInProgress => 'In progress';

  @override
  String get featureTrailer => 'Trailer';

  @override
  String get featureExtras => 'Extras';

  @override
  String get featureThemeSong => 'Theme song';

  @override
  String get featureThemeVideo => 'Theme video';

  @override
  String get filterApply => 'Apply';

  @override
  String get filterReset => 'Reset';

  @override
  String get nothingToFilterBy =>
      'This library holds nothing else to filter by.';

  @override
  String get heroResume => 'Resume';

  @override
  String get heroDetails => 'Details';

  @override
  String get downloadsEmptyHint =>
      'Download a film or an episode from its page to watch it here without a connection.';

  @override
  String get addedToDownloads => 'Added to downloads';

  @override
  String get downloadQueued => 'Queued';

  @override
  String downloadingPercent(int percent) {
    return 'Downloading · $percent%';
  }

  @override
  String get downloadPaused => 'Paused';

  @override
  String get resumeDownload => 'Resume download';

  @override
  String get retryDownload => 'Try again';

  @override
  String get removeDownload => 'Remove download';

  @override
  String get removeDownloadTitle => 'Remove this download?';

  @override
  String removeDownloadBody(String title) {
    return '$title will no longer be available offline.';
  }

  @override
  String downloadAllTitle(int count) {
    return 'Download $count episodes?';
  }

  @override
  String get downloadAllBody =>
      'They are saved one at a time, in the original quality, and can take a lot of space.';

  @override
  String get allDownloaded => 'Every episode is already downloaded';

  @override
  String get downloadsInProgress => 'In progress';

  @override
  String get downloadsCompleted => 'Downloaded';

  @override
  String get downloadsMovies => 'Films';

  @override
  String downloadSizeOf(String received, String total) {
    return '$received of $total';
  }

  @override
  String get downloadWaitingForServer => 'Waiting for the server to sign in';

  @override
  String downloadsUsed(String size) {
    return '$size on this device';
  }

  @override
  String get watchDownloads => 'Watch downloads';

  @override
  String downloadsQueuedMore(int count) {
    return '$count more queued';
  }

  @override
  String get downloadWaitingForWifi => 'Waiting for Wi-Fi';

  @override
  String get downloadWaitingForNetwork => 'Waiting for a connection';

  @override
  String get downloadSettings => 'Downloads';

  @override
  String get downloadSettingsSub => 'Wi-Fi only, storage';

  @override
  String get downloadWifiOnly => 'Download on Wi-Fi only';

  @override
  String get downloadWifiOnlySub =>
      'Hold the queue on mobile data and carry on when Wi-Fi is back';

  @override
  String get downloadRemoveWatched => 'Remove watched downloads';

  @override
  String get downloadRemoveWatchedSub =>
      'Delete a copy once it has been watched to the end on this device';

  @override
  String get downloadStorage => 'Storage';

  @override
  String get downloadRemoveAll => 'Remove all downloads';

  @override
  String get downloadRemoveAllTitle => 'Remove every download?';

  @override
  String get downloadRemoveAllBody =>
      'Everything saved on this device for offline viewing will be deleted.';

  @override
  String get downloadsNone => 'Nothing is downloaded on this device.';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabArtists => 'Artists';

  @override
  String get tabSongs => 'Songs';

  @override
  String get noAlbums => 'No albums here.';

  @override
  String get noArtists => 'No artists here.';

  @override
  String get noSongs => 'No songs here.';

  @override
  String get musicLoadFailed => 'Could not load this from the server.';

  @override
  String get sortArtist => 'Artist';

  @override
  String discNumber(int number) {
    return 'Disc $number';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get popularTracks => 'Popular';

  @override
  String get seeAllTracks => 'See all';

  @override
  String get appearsOn => 'Appears on';

  @override
  String get similarArtists => 'Similar artists';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get queue => 'Queue';

  @override
  String get queueEmpty => 'Nothing else is queued.';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get stopPlayback => 'Stop';

  @override
  String get repeatOff => 'Repeat is off';

  @override
  String get repeatOne => 'Repeating this song';

  @override
  String get repeatAll => 'Repeating the queue';

  @override
  String get playNextInQueue => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get instantMix => 'Instant mix';

  @override
  String get noInstantMix => 'The server has no mix for this.';

  @override
  String get recentlyPlayed => 'Recently played';
}
