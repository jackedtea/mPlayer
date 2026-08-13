import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'mPlayer'**
  String get appTitle;

  /// No description provided for @navStorage.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get navStorage;

  /// No description provided for @navServer.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get navServer;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get actionTest;

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get actionConnect;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @actionSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get actionSort;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get viewList;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get viewGrid;

  /// No description provided for @notImplemented.
  ///
  /// In en, this message translates to:
  /// **'{feature} — not implemented yet'**
  String notImplemented(String feature);

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatching;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @openFileOrFolder.
  ///
  /// In en, this message translates to:
  /// **'Open a file or folder'**
  String get openFileOrFolder;

  /// No description provided for @addShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Add SMB, WebDAV or NFS'**
  String get addShareTitle;

  /// No description provided for @addShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Or scan the local network'**
  String get addShareSubtitle;

  /// No description provided for @driverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{kind} — driver not available yet'**
  String driverUnavailable(String kind);

  /// No description provided for @shareOptions.
  ///
  /// In en, this message translates to:
  /// **'Share options'**
  String get shareOptions;

  /// No description provided for @removeShare.
  ///
  /// In en, this message translates to:
  /// **'Remove share'**
  String get removeShare;

  /// No description provided for @removeShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Its saved password is deleted too'**
  String get removeShareSubtitle;

  /// No description provided for @addShareHeading.
  ///
  /// In en, this message translates to:
  /// **'Add a share'**
  String get addShareHeading;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @anonymousHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for an anonymous share'**
  String get anonymousHint;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @noDriverNotice.
  ///
  /// In en, this message translates to:
  /// **'{kind} has no driver yet. The share will be saved and listed, but cannot be browsed until it lands.'**
  String noDriverNotice(String kind);

  /// No description provided for @connectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connected — {folders} folders, {files} files'**
  String connectionOk(int folders, int files);

  /// No description provided for @folderCounts.
  ///
  /// In en, this message translates to:
  /// **'{folders} folders · {files} files'**
  String folderCounts(int folders, int files);

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get reading;

  /// No description provided for @directPlay.
  ///
  /// In en, this message translates to:
  /// **'Direct play'**
  String get directPlay;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyFolder;

  /// No description provided for @couldNotReadFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not read this folder.'**
  String get couldNotReadFolder;

  /// No description provided for @notAVideo.
  ///
  /// In en, this message translates to:
  /// **'{name} is not a video file'**
  String notAVideo(String name);

  /// No description provided for @noServerTitle.
  ///
  /// In en, this message translates to:
  /// **'No media server yet'**
  String get noServerTitle;

  /// No description provided for @noServerBody.
  ///
  /// In en, this message translates to:
  /// **'Everything on this device and your network shares already works without one. Add a Jellyfin server to sync watch state, metadata and remote access.'**
  String get noServerBody;

  /// No description provided for @addJellyfinServer.
  ///
  /// In en, this message translates to:
  /// **'Add Jellyfin server'**
  String get addJellyfinServer;

  /// No description provided for @scanNetwork.
  ///
  /// In en, this message translates to:
  /// **'Scan this network'**
  String get scanNetwork;

  /// No description provided for @otherServersNotice.
  ///
  /// In en, this message translates to:
  /// **'Emby and Plex servers can be added here too — the tab is not Jellyfin-only.'**
  String get otherServersNotice;

  /// No description provided for @previewConnectedServer.
  ///
  /// In en, this message translates to:
  /// **'Preview a connected server'**
  String get previewConnectedServer;

  /// No description provided for @addServerHeading.
  ///
  /// In en, this message translates to:
  /// **'Add a server'**
  String get addServerHeading;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @detectHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an address to detect the server'**
  String get detectHint;

  /// No description provided for @detectPending.
  ///
  /// In en, this message translates to:
  /// **'Detection runs once the Jellyfin client lands'**
  String get detectPending;

  /// No description provided for @quickConnect.
  ///
  /// In en, this message translates to:
  /// **'Quick connect instead'**
  String get quickConnect;

  /// No description provided for @quickConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approve from another signed-in device'**
  String get quickConnectSubtitle;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @libraries.
  ///
  /// In en, this message translates to:
  /// **'Libraries'**
  String get libraries;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemCount(int count);

  /// No description provided for @unwatched.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get unwatched;

  /// No description provided for @unwatchedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unwatched'**
  String unwatchedCount(int count);

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @cast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get cast;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @searchEverything.
  ///
  /// In en, this message translates to:
  /// **'Search everything'**
  String get searchEverything;

  /// No description provided for @voiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Voice search'**
  String get voiceSearch;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @whereToLook.
  ///
  /// In en, this message translates to:
  /// **'Where to look'**
  String get whereToLook;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// No description provided for @backToSources.
  ///
  /// In en, this message translates to:
  /// **'Back to sources'**
  String get backToSources;

  /// No description provided for @showMoreFrom.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more from {source}'**
  String showMoreFrom(int count, String source);

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @nothingDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Nothing downloaded'**
  String get nothingDownloaded;

  /// No description provided for @downloadsBody.
  ///
  /// In en, this message translates to:
  /// **'Downloads are queued on Wi-Fi by default and expire per the server\'s policy.'**
  String get downloadsBody;

  /// No description provided for @pauseDownload.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseDownload;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelDownload;

  /// No description provided for @availableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get availableOffline;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSub.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent colour, density'**
  String get settingsAppearanceSub;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsGeneralSub.
  ///
  /// In en, this message translates to:
  /// **'Language, startup tab, cache'**
  String get settingsGeneralSub;

  /// No description provided for @settingsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get settingsPlayer;

  /// No description provided for @settingsPlayerSub.
  ///
  /// In en, this message translates to:
  /// **'Decoding, gestures, streaming quality'**
  String get settingsPlayerSub;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsAudioSub.
  ///
  /// In en, this message translates to:
  /// **'Passthrough, track language, boost'**
  String get settingsAudioSub;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get settingsSubtitle;

  /// No description provided for @settingsSubtitleSub.
  ///
  /// In en, this message translates to:
  /// **'Style, language order, sync offset'**
  String get settingsSubtitleSub;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSub.
  ///
  /// In en, this message translates to:
  /// **'Version, licences, diagnostics'**
  String get settingsAboutSub;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// No description provided for @dynamicColour.
  ///
  /// In en, this message translates to:
  /// **'Material You dynamic colour'**
  String get dynamicColour;

  /// No description provided for @dynamicColourSub.
  ///
  /// In en, this message translates to:
  /// **'Follow the system wallpaper palette'**
  String get dynamicColourSub;

  /// No description provided for @pureBlack.
  ///
  /// In en, this message translates to:
  /// **'Pure black in dark mode'**
  String get pureBlack;

  /// No description provided for @pureBlackSub.
  ///
  /// In en, this message translates to:
  /// **'Saves power on OLED screens'**
  String get pureBlackSub;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @defaultLibraryView.
  ///
  /// In en, this message translates to:
  /// **'Default library view'**
  String get defaultLibraryView;

  /// No description provided for @density.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get density;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @hardwareDecoding.
  ///
  /// In en, this message translates to:
  /// **'Hardware decoding'**
  String get hardwareDecoding;

  /// No description provided for @hardwareDecodingValue.
  ///
  /// In en, this message translates to:
  /// **'Auto (safe)'**
  String get hardwareDecodingValue;

  /// No description provided for @hardwareDecodingSub.
  ///
  /// In en, this message translates to:
  /// **'Falls back to software when a codec is unsupported'**
  String get hardwareDecodingSub;

  /// No description provided for @resumeBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Resume behaviour'**
  String get resumeBehaviour;

  /// No description provided for @skipBack.
  ///
  /// In en, this message translates to:
  /// **'Skip back'**
  String get skipBack;

  /// No description provided for @skipForward.
  ///
  /// In en, this message translates to:
  /// **'Skip forward'**
  String get skipForward;

  /// No description provided for @autoPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Auto-play next episode'**
  String get autoPlayNext;

  /// No description provided for @autoSkipIntro.
  ///
  /// In en, this message translates to:
  /// **'Auto skip intro'**
  String get autoSkipIntro;

  /// No description provided for @autoSkipIntroSub.
  ///
  /// In en, this message translates to:
  /// **'Only where the server marks an intro chapter'**
  String get autoSkipIntroSub;

  /// No description provided for @screenAndGestures.
  ///
  /// In en, this message translates to:
  /// **'Screen & gestures'**
  String get screenAndGestures;

  /// No description provided for @rotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get rotation;

  /// No description provided for @rotationFollowVideo.
  ///
  /// In en, this message translates to:
  /// **'Follow video'**
  String get rotationFollowVideo;

  /// No description provided for @swipeGestures.
  ///
  /// In en, this message translates to:
  /// **'Swipe gestures'**
  String get swipeGestures;

  /// No description provided for @swipeGesturesSub.
  ///
  /// In en, this message translates to:
  /// **'Brightness on the left, volume on the right'**
  String get swipeGesturesSub;

  /// No description provided for @backgroundPip.
  ///
  /// In en, this message translates to:
  /// **'Background & picture-in-picture'**
  String get backgroundPip;

  /// No description provided for @streamingQuality.
  ///
  /// In en, this message translates to:
  /// **'Streaming quality'**
  String get streamingQuality;

  /// No description provided for @onWifi.
  ///
  /// In en, this message translates to:
  /// **'On Wi-Fi'**
  String get onWifi;

  /// No description provided for @onCellular.
  ///
  /// In en, this message translates to:
  /// **'On cellular'**
  String get onCellular;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @megabitsPerSecond.
  ///
  /// In en, this message translates to:
  /// **'{value} Mbps'**
  String megabitsPerSecond(int value);

  /// No description provided for @style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get style;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @backgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get backgroundOpacity;

  /// No description provided for @behaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get behaviour;

  /// No description provided for @preferredLanguages.
  ///
  /// In en, this message translates to:
  /// **'Preferred languages'**
  String get preferredLanguages;

  /// No description provided for @burnInWhenTranscoding.
  ///
  /// In en, this message translates to:
  /// **'Burn in when transcoding'**
  String get burnInWhenTranscoding;

  /// No description provided for @burnInSub.
  ///
  /// In en, this message translates to:
  /// **'Image-based subtitles only'**
  String get burnInSub;

  /// No description provided for @syncOffset.
  ///
  /// In en, this message translates to:
  /// **'Sync offset'**
  String get syncOffset;

  /// No description provided for @subtitlePreview.
  ///
  /// In en, this message translates to:
  /// **'The tide turns at midnight.'**
  String get subtitlePreview;

  /// No description provided for @percent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percent(int value);

  /// No description provided for @versionAndBuild.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · build {build}'**
  String versionAndBuild(String version, String build);

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get upToDate;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @releaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get releaseNotes;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @openSourceLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get openSourceLicences;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @thisDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDeviceInfo;

  /// No description provided for @notAffiliated.
  ///
  /// In en, this message translates to:
  /// **'mPlayer is not affiliated with, endorsed by, or sponsored by the Jellyfin, Emby or Plex projects.'**
  String get notAffiliated;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @noChapters.
  ///
  /// In en, this message translates to:
  /// **'This file has no chapters'**
  String get noChapters;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @skipIntro.
  ///
  /// In en, this message translates to:
  /// **'Skip intro'**
  String get skipIntro;

  /// No description provided for @lockPlayer.
  ///
  /// In en, this message translates to:
  /// **'Lock player'**
  String get lockPlayer;

  /// No description provided for @screenLocked.
  ///
  /// In en, this message translates to:
  /// **'Screen locked'**
  String get screenLocked;

  /// No description provided for @unlockHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the lock twice to unlock'**
  String get unlockHint;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @pictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture in picture'**
  String get pictureInPicture;

  /// No description provided for @castTo.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get castTo;

  /// No description provided for @aspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get aspectRatio;

  /// No description provided for @aspectFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get aspectFit;

  /// No description provided for @aspectFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get aspectFill;

  /// No description provided for @aspectStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get aspectStretch;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutes(int count);

  /// No description provided for @statsForNerds.
  ///
  /// In en, this message translates to:
  /// **'Stats for nerds'**
  String get statsForNerds;

  /// No description provided for @playerSettings.
  ///
  /// In en, this message translates to:
  /// **'Player settings'**
  String get playerSettings;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @back10.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get back10;

  /// No description provided for @forward30.
  ///
  /// In en, this message translates to:
  /// **'Forward 30 seconds'**
  String get forward30;

  /// No description provided for @nothingToPlay.
  ///
  /// In en, this message translates to:
  /// **'Nothing to play — pick a file from Files.'**
  String get nothingToPlay;

  /// No description provided for @rotationAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get rotationAuto;

  /// No description provided for @rotationLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get rotationLandscape;

  /// No description provided for @rotationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get rotationPortrait;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @offlineSkipped.
  ///
  /// In en, this message translates to:
  /// **'Offline — will be skipped'**
  String get offlineSkipped;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
