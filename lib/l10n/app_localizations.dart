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

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open a file'**
  String get openFile;

  /// No description provided for @selectMore.
  ///
  /// In en, this message translates to:
  /// **'Select more'**
  String get selectMore;

  /// No description provided for @partialAccessNotice.
  ///
  /// In en, this message translates to:
  /// **'Only the videos you shared are listed.'**
  String get partialAccessNotice;

  /// No description provided for @noVideosOnDevice.
  ///
  /// In en, this message translates to:
  /// **'No videos found on this device yet.'**
  String get noVideosOnDevice;

  /// No description provided for @mediaAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow mPlayer to find your videos'**
  String get mediaAccessTitle;

  /// No description provided for @mediaAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Android does not let apps browse storage directly, so the system media index is used instead.'**
  String get mediaAccessBody;

  /// No description provided for @videoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 video} other{{count} videos}}'**
  String videoCount(int count);

  /// No description provided for @addShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Add SMB or WebDAV'**
  String get addShareTitle;

  /// No description provided for @addShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A share on your network'**
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
  /// **'Back {seconds} seconds'**
  String back10(int seconds);

  /// No description provided for @forward30.
  ///
  /// In en, this message translates to:
  /// **'Forward {seconds} seconds'**
  String forward30(int seconds);

  /// No description provided for @nothingToPlay.
  ///
  /// In en, this message translates to:
  /// **'Nothing to play — pick a file from Files.'**
  String get nothingToPlay;

  /// No description provided for @previousFile.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousFile;

  /// No description provided for @nextFile.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextFile;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @aspectRatioValue.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio: {mode}'**
  String aspectRatioValue(String mode);

  /// No description provided for @rotationValue.
  ///
  /// In en, this message translates to:
  /// **'Rotation: {mode}'**
  String rotationValue(String mode);

  /// No description provided for @subtitlesValue.
  ///
  /// In en, this message translates to:
  /// **'Subtitles: {track}'**
  String subtitlesValue(String track);

  /// No description provided for @audioValue.
  ///
  /// In en, this message translates to:
  /// **'Audio: {track}'**
  String audioValue(String track);

  /// No description provided for @speedValue.
  ///
  /// In en, this message translates to:
  /// **'Speed: {speed}×'**
  String speedValue(String speed);

  /// No description provided for @audioDelay.
  ///
  /// In en, this message translates to:
  /// **'Audio delay'**
  String get audioDelay;

  /// No description provided for @openSubtitleFile.
  ///
  /// In en, this message translates to:
  /// **'Open subtitle file…'**
  String get openSubtitleFile;

  /// No description provided for @playOn.
  ///
  /// In en, this message translates to:
  /// **'Play on'**
  String get playOn;

  /// No description provided for @searchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get searchAgain;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Check that the television is on and on the same network.'**
  String get noDevicesFound;

  /// No description provided for @stopCasting.
  ///
  /// In en, this message translates to:
  /// **'Stop casting'**
  String get stopCasting;

  /// No description provided for @playingOn.
  ///
  /// In en, this message translates to:
  /// **'Playing on {device}'**
  String playingOn(String device);

  /// No description provided for @couldNotCast.
  ///
  /// In en, this message translates to:
  /// **'Could not cast to that device.'**
  String get couldNotCast;

  /// No description provided for @grantedFolder.
  ///
  /// In en, this message translates to:
  /// **'Granted folder'**
  String get grantedFolder;

  /// No description provided for @removeFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get removeFolder;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add a folder'**
  String get addFolder;

  /// No description provided for @addFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For videos the media index does not list'**
  String get addFolderSubtitle;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allowAccess;

  /// No description provided for @editShare.
  ///
  /// In en, this message translates to:
  /// **'Edit share'**
  String get editShare;

  /// No description provided for @editShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change its name, address or credentials'**
  String get editShareSubtitle;

  /// No description provided for @hardwareDecodingFallback.
  ///
  /// In en, this message translates to:
  /// **'Falls back to software when a codec is unsupported'**
  String get hardwareDecodingFallback;

  /// No description provided for @audioDelaySub.
  ///
  /// In en, this message translates to:
  /// **'Shifts the sound against the picture'**
  String get audioDelaySub;

  /// No description provided for @autoPlayNextSub.
  ///
  /// In en, this message translates to:
  /// **'Continues with the next video in the folder'**
  String get autoPlayNextSub;

  /// No description provided for @pictureInPictureSub.
  ///
  /// In en, this message translates to:
  /// **'Shrink into a floating window when you leave the app'**
  String get pictureInPictureSub;

  /// No description provided for @backgroundAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio in background'**
  String get backgroundAudio;

  /// No description provided for @backgroundAudioSub.
  ///
  /// In en, this message translates to:
  /// **'Keeps playing with the screen off, with a notification'**
  String get backgroundAudioSub;

  /// No description provided for @followVideo.
  ///
  /// In en, this message translates to:
  /// **'Follow video'**
  String get followVideo;

  /// No description provided for @needsTranscodingServer.
  ///
  /// In en, this message translates to:
  /// **'Needs a server that can transcode'**
  String get needsTranscodingServer;

  /// No description provided for @noPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get noPreference;

  /// No description provided for @noPreferenceSub.
  ///
  /// In en, this message translates to:
  /// **'Leave the tracks the file chose'**
  String get noPreferenceSub;

  /// No description provided for @preferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get preferredLanguage;

  /// No description provided for @preferredLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'The language you would rather hear and read'**
  String get preferredLanguageSub;

  /// No description provided for @smartSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Smart subtitles'**
  String get smartSubtitles;

  /// No description provided for @smartSubtitlesSub.
  ///
  /// In en, this message translates to:
  /// **'Subtitles only when the audio is in another language'**
  String get smartSubtitlesSub;

  /// No description provided for @imageBasedOnly.
  ///
  /// In en, this message translates to:
  /// **'Image-based subtitles only'**
  String get imageBasedOnly;

  /// No description provided for @syncOffsetSub.
  ///
  /// In en, this message translates to:
  /// **'Positive delays the subtitles'**
  String get syncOffsetSub;

  /// No description provided for @subtitlePreviewLine.
  ///
  /// In en, this message translates to:
  /// **'The tide turns at midnight.'**
  String get subtitlePreviewLine;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @audioOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get audioOutput;

  /// No description provided for @passthrough.
  ///
  /// In en, this message translates to:
  /// **'Bitstream passthrough'**
  String get passthrough;

  /// No description provided for @passthroughSub.
  ///
  /// In en, this message translates to:
  /// **'Send AC3, DTS, E-AC3 and TrueHD to the amplifier undecoded'**
  String get passthroughSub;

  /// No description provided for @passthroughNote.
  ///
  /// In en, this message translates to:
  /// **'Turn this on only if a receiver or soundbar is decoding for you. Without one, passthrough plays silence.'**
  String get passthroughNote;

  /// No description provided for @volumeBoost.
  ///
  /// In en, this message translates to:
  /// **'Volume boost'**
  String get volumeBoost;

  /// No description provided for @volumeBoostNote.
  ///
  /// In en, this message translates to:
  /// **'The ceiling for the volume gesture. Above 100% the sound is amplified, which rescues a quiet film and can clip a loud one.'**
  String get volumeBoostNote;

  /// No description provided for @gapless.
  ///
  /// In en, this message translates to:
  /// **'Gapless playback'**
  String get gapless;

  /// No description provided for @gaplessSub.
  ///
  /// In en, this message translates to:
  /// **'How hard to try to run one file into the next'**
  String get gaplessSub;

  /// No description provided for @gaplessOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get gaplessOff;

  /// No description provided for @gaplessOffSub.
  ///
  /// In en, this message translates to:
  /// **'Always reinitialise between files'**
  String get gaplessOffSub;

  /// No description provided for @gaplessAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get gaplessAutomatic;

  /// No description provided for @gaplessAutomaticSub.
  ///
  /// In en, this message translates to:
  /// **'Gapless when the next file matches'**
  String get gaplessAutomaticSub;

  /// No description provided for @gaplessAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get gaplessAlways;

  /// No description provided for @gaplessAlwaysSub.
  ///
  /// In en, this message translates to:
  /// **'Gapless even if it means resampling'**
  String get gaplessAlwaysSub;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @sharedWithSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Shared with Subtitle settings'**
  String get sharedWithSubtitles;

  /// No description provided for @checkForUpdatesSub.
  ///
  /// In en, this message translates to:
  /// **'Asks GitHub once. Nothing about you or the device is sent'**
  String get checkForUpdatesSub;

  /// No description provided for @diagnosticsSub.
  ///
  /// In en, this message translates to:
  /// **'Build, device and the player log, for a bug report'**
  String get diagnosticsSub;

  /// No description provided for @privacySub.
  ///
  /// In en, this message translates to:
  /// **'What leaves this device, and what does not'**
  String get privacySub;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is out'**
  String updateAvailable(String version);

  /// No description provided for @couldNotCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not check'**
  String get couldNotCheck;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String couldNotOpen(String url);

  /// No description provided for @build.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get build;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @applicationId.
  ///
  /// In en, this message translates to:
  /// **'Application id'**
  String get applicationId;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @operatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Operating system'**
  String get operatingSystem;

  /// No description provided for @locale.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get locale;

  /// No description provided for @screen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get screen;

  /// No description provided for @playerLog.
  ///
  /// In en, this message translates to:
  /// **'Player log'**
  String get playerLog;

  /// No description provided for @copyEverything.
  ///
  /// In en, this message translates to:
  /// **'Copy everything'**
  String get copyEverything;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied'**
  String get diagnosticsCopied;

  /// No description provided for @logEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. The log fills while a file is playing, and is kept only for the current session.'**
  String get logEmpty;

  /// No description provided for @privacyNoTelemetry.
  ///
  /// In en, this message translates to:
  /// **'No analytics, no telemetry, no crash reporting'**
  String get privacyNoTelemetry;

  /// No description provided for @privacyNoTelemetryBody.
  ///
  /// In en, this message translates to:
  /// **'There is no third-party SDK collecting anything. mPlayer contacts the servers and shares you configure, and nothing else.'**
  String get privacyNoTelemetryBody;

  /// No description provided for @privacyLocal.
  ///
  /// In en, this message translates to:
  /// **'Your library stays on your device'**
  String get privacyLocal;

  /// No description provided for @privacyLocalBody.
  ///
  /// In en, this message translates to:
  /// **'What you watch, where you got to and the stills on the Continue watching shelf are stored locally. None of it leaves the device.'**
  String get privacyLocalBody;

  /// No description provided for @privacyKeychain.
  ///
  /// In en, this message translates to:
  /// **'Passwords live in the system keychain'**
  String get privacyKeychain;

  /// No description provided for @privacyKeychainBody.
  ///
  /// In en, this message translates to:
  /// **'Share and server credentials go to the platform secure storage, never into ordinary preferences alongside the rest of the settings.'**
  String get privacyKeychainBody;

  /// No description provided for @privacyUpdates.
  ///
  /// In en, this message translates to:
  /// **'Update checks are manual'**
  String get privacyUpdates;

  /// No description provided for @privacyUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is checked on launch. Pressing \"Check for updates\" makes one anonymous request to the GitHub releases API — no identifier is sent with it.'**
  String get privacyUpdatesBody;

  /// No description provided for @privacyCasting.
  ///
  /// In en, this message translates to:
  /// **'Casting opens a server on your network'**
  String get privacyCasting;

  /// No description provided for @privacyCastingBody.
  ///
  /// In en, this message translates to:
  /// **'While a cast is running, the file being played is served over the local network so the television can fetch it. That server stops when the cast does.'**
  String get privacyCastingBody;

  /// No description provided for @privacyFooter.
  ///
  /// In en, this message translates to:
  /// **'mPlayer is free software under the GPL-3.0-or-later. You can read the source and check every claim on this page for yourself.'**
  String get privacyFooter;

  /// No description provided for @noChaptersInFile.
  ///
  /// In en, this message translates to:
  /// **'This file has no chapters'**
  String get noChaptersInFile;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @milliseconds.
  ///
  /// In en, this message translates to:
  /// **'{count} ms'**
  String milliseconds(int count);

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String seconds(int count);

  /// No description provided for @timeLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String timeLeft(String time);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistName;

  /// No description provided for @markWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as watched'**
  String get markWatched;

  /// No description provided for @markUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as unwatched'**
  String get markUnwatched;

  /// No description provided for @addFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addFavourite;

  /// No description provided for @removeFavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFavourite;

  /// No description provided for @shufflePlay.
  ///
  /// In en, this message translates to:
  /// **'Shuffle play'**
  String get shufflePlay;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get downloadAll;

  /// No description provided for @mediaInfo.
  ///
  /// In en, this message translates to:
  /// **'Media info'**
  String get mediaInfo;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'The server would not do that.'**
  String get actionFailed;

  /// No description provided for @audioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioTrack;

  /// No description provided for @subtitleTrack.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitleTrack;

  /// No description provided for @subtitlesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get subtitlesOff;

  /// No description provided for @serverDefault.
  ///
  /// In en, this message translates to:
  /// **'Server default'**
  String get serverDefault;

  /// No description provided for @switchServer.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get switchServer;

  /// No description provided for @editServer.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServer;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @removeServer.
  ///
  /// In en, this message translates to:
  /// **'Remove server'**
  String get removeServer;

  /// No description provided for @removeServerBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be forgotten, along with its sign-in. Nothing on the server itself is deleted.'**
  String removeServerBody(Object name);

  /// No description provided for @qualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get qualityOriginal;

  /// No description provided for @qualityOriginalDetail.
  ///
  /// In en, this message translates to:
  /// **'Never re-encode. Best picture, and the only option that works offline of the the server\'s own CPU.'**
  String get qualityOriginalDetail;

  /// No description provided for @playbackQuality.
  ///
  /// In en, this message translates to:
  /// **'Playback quality'**
  String get playbackQuality;

  /// No description provided for @episodeOf.
  ///
  /// In en, this message translates to:
  /// **'S{season}E{episode}'**
  String episodeOf(int season, int episode);

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(String name);

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'The stored sign-in still works'**
  String get signInAgain;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @noServersYet.
  ///
  /// In en, this message translates to:
  /// **'No servers yet.'**
  String get noServersYet;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @quickConnectInstead.
  ///
  /// In en, this message translates to:
  /// **'Quick connect instead'**
  String get quickConnectInstead;

  /// No description provided for @quickConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Approve from another signed-in device'**
  String get quickConnectHint;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @getACode.
  ///
  /// In en, this message translates to:
  /// **'Get a code'**
  String get getACode;

  /// No description provided for @enterCodeInJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Enter this code in Jellyfin'**
  String get enterCodeInJellyfin;

  /// No description provided for @serverTab.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverTab;

  /// No description provided for @searchThisServer.
  ///
  /// In en, this message translates to:
  /// **'Search this server'**
  String get searchThisServer;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here.'**
  String get nothingHere;

  /// No description provided for @moreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More like this'**
  String get moreLikeThis;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @studios.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get studios;

  /// No description provided for @seriesStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get seriesStatus;

  /// No description provided for @statusContinuing.
  ///
  /// In en, this message translates to:
  /// **'Continuing'**
  String get statusContinuing;

  /// No description provided for @statusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get statusEnded;

  /// No description provided for @gridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid size'**
  String get gridSize;

  /// No description provided for @gridColumns.
  ///
  /// In en, this message translates to:
  /// **'{count} per row'**
  String gridColumns(int count);

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get sortName;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sortDateAdded;

  /// No description provided for @sortReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release date'**
  String get sortReleaseDate;

  /// No description provided for @sortDatePlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get sortDatePlayed;

  /// No description provided for @sortRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get sortRandom;

  /// No description provided for @resumeAt.
  ///
  /// In en, this message translates to:
  /// **'Resume · {time}'**
  String resumeAt(String time);

  /// No description provided for @watched.
  ///
  /// In en, this message translates to:
  /// **'watched'**
  String get watched;

  /// No description provided for @episodeNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get episodeNew;

  /// No description provided for @seasonCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seasons'**
  String seasonCount(int count);

  /// No description provided for @episodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes'**
  String episodeCount(int count);

  /// No description provided for @seasonNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seasonNumber(int number);

  /// No description provided for @specials.
  ///
  /// In en, this message translates to:
  /// **'Specials'**
  String get specials;

  /// No description provided for @kindMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get kindMovie;

  /// No description provided for @kindSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get kindSeries;

  /// No description provided for @kindSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get kindSeason;

  /// No description provided for @kindEpisode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get kindEpisode;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched that'**
  String get noResults;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAll;

  /// No description provided for @clearContinueWatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Continue watching?'**
  String get clearContinueWatchingTitle;

  /// No description provided for @clearContinueWatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Every saved position is forgotten, on this device only. Nothing is deleted from your shares or your server.'**
  String get clearContinueWatchingBody;

  /// No description provided for @continueWatchingCleared.
  ///
  /// In en, this message translates to:
  /// **'Continue watching cleared'**
  String get continueWatchingCleared;

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
