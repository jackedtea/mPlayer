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

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @tabBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get tabBrowse;

  /// No description provided for @recentlyAddedIn.
  ///
  /// In en, this message translates to:
  /// **'Recently added in {library}'**
  String recentlyAddedIn(String library);

  /// No description provided for @customizeHome.
  ///
  /// In en, this message translates to:
  /// **'Customize home'**
  String get customizeHome;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @customizeHomeSub.
  ///
  /// In en, this message translates to:
  /// **'Choose which libraries show their newest items. Saved to your account on the server, so the web app shows the same.'**
  String get customizeHomeSub;

  /// No description provided for @changeServer.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get changeServer;

  /// No description provided for @chooseServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a server from the Home tab first.'**
  String get chooseServerFirst;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionServer.
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get settingsSectionServer;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'Nothing downloaded'**
  String get noDownloads;

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

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get actionConnect;

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

  /// No description provided for @driverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{kind} — driver not available yet'**
  String driverUnavailable(String kind);

  /// No description provided for @addShareHeading.
  ///
  /// In en, this message translates to:
  /// **'Add a share'**
  String get addShareHeading;

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

  /// No description provided for @noServerTitle.
  ///
  /// In en, this message translates to:
  /// **'No media server yet'**
  String get noServerTitle;

  /// No description provided for @noServerBody.
  ///
  /// In en, this message translates to:
  /// **'mPlayer plays what a media server gives it. Add a Jellyfin server to browse your library, keep your watch state in step across devices, and reach it from anywhere.'**
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
  /// **'mPlayer works with Jellyfin servers. Emby and Plex are not supported.'**
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

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favourites;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @onThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device'**
  String get onThisDevice;

  /// No description provided for @noFavouritesYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing starred yet. Tap the heart on a film, a show or an episode and it will be here.'**
  String get noFavouritesYet;

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

  /// No description provided for @switchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Switch library'**
  String get switchLibrary;

  /// No description provided for @settingsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Server administration'**
  String get settingsAdmin;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(int count);

  /// No description provided for @settingsAdminSub.
  ///
  /// In en, this message translates to:
  /// **'Sessions, tasks, users, plugins'**
  String get settingsAdminSub;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get adminTitle;

  /// No description provided for @adminNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'This account is not an administrator.'**
  String get adminNotAdmin;

  /// No description provided for @adminNoServer.
  ///
  /// In en, this message translates to:
  /// **'Sign in to a server first.'**
  String get adminNoServer;

  /// No description provided for @adminServerSection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get adminServerSection;

  /// No description provided for @adminSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get adminSessions;

  /// No description provided for @adminNoSessions.
  ///
  /// In en, this message translates to:
  /// **'Nobody is connected.'**
  String get adminNoSessions;

  /// No description provided for @adminIdleSession.
  ///
  /// In en, this message translates to:
  /// **'Connected, not playing'**
  String get adminIdleSession;

  /// No description provided for @adminStopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get adminStopPlayback;

  /// No description provided for @adminSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get adminSendMessage;

  /// No description provided for @adminMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Message to {device}'**
  String adminMessageTitle(String device);

  /// No description provided for @adminMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What should it say?'**
  String get adminMessageHint;

  /// No description provided for @adminMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent.'**
  String get adminMessageSent;

  /// No description provided for @adminPlaybackStopped.
  ///
  /// In en, this message translates to:
  /// **'Playback stopped.'**
  String get adminPlaybackStopped;

  /// No description provided for @adminTasks.
  ///
  /// In en, this message translates to:
  /// **'Scheduled tasks'**
  String get adminTasks;

  /// No description provided for @adminNoTasks.
  ///
  /// In en, this message translates to:
  /// **'This server lists no tasks.'**
  String get adminNoTasks;

  /// No description provided for @adminRunTask.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get adminRunTask;

  /// No description provided for @adminStopTask.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get adminStopTask;

  /// No description provided for @adminTaskStarted.
  ///
  /// In en, this message translates to:
  /// **'{name} started.'**
  String adminTaskStarted(String name);

  /// No description provided for @adminTaskStopping.
  ///
  /// In en, this message translates to:
  /// **'{name} is being stopped.'**
  String adminTaskStopping(String name);

  /// No description provided for @adminTaskNeverRun.
  ///
  /// In en, this message translates to:
  /// **'Never run'**
  String get adminTaskNeverRun;

  /// No description provided for @adminTaskLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run {when}'**
  String adminTaskLastRun(String when);

  /// No description provided for @adminTaskLastFailed.
  ///
  /// In en, this message translates to:
  /// **'Last run failed'**
  String get adminTaskLastFailed;

  /// No description provided for @adminScanLibraries.
  ///
  /// In en, this message translates to:
  /// **'Scan all libraries'**
  String get adminScanLibraries;

  /// No description provided for @adminScanStarted.
  ///
  /// In en, this message translates to:
  /// **'Library scan started.'**
  String get adminScanStarted;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// No description provided for @adminNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No accounts on this server.'**
  String get adminNoUsers;

  /// No description provided for @adminUserAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminUserAdmin;

  /// No description provided for @adminUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminUserDisabled;

  /// No description provided for @adminUserEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get adminUserEnable;

  /// No description provided for @adminUserDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get adminUserDisable;

  /// No description provided for @adminUserEnabled.
  ///
  /// In en, this message translates to:
  /// **'{name} can sign in again.'**
  String adminUserEnabled(String name);

  /// No description provided for @adminUserNowDisabled.
  ///
  /// In en, this message translates to:
  /// **'{name} can no longer sign in.'**
  String adminUserNowDisabled(String name);

  /// No description provided for @adminDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get adminDevices;

  /// No description provided for @adminNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices have signed in.'**
  String get adminNoDevices;

  /// No description provided for @adminForgetDevice.
  ///
  /// In en, this message translates to:
  /// **'Forget this device'**
  String get adminForgetDevice;

  /// No description provided for @adminDeviceForgotten.
  ///
  /// In en, this message translates to:
  /// **'Device forgotten.'**
  String get adminDeviceForgotten;

  /// No description provided for @adminActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get adminActivity;

  /// No description provided for @adminNoActivity.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been logged yet.'**
  String get adminNoActivity;

  /// No description provided for @adminPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get adminPlugins;

  /// No description provided for @adminNoPlugins.
  ///
  /// In en, this message translates to:
  /// **'No plugins are installed.'**
  String get adminNoPlugins;

  /// No description provided for @adminPluginEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get adminPluginEnable;

  /// No description provided for @adminPluginDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get adminPluginDisable;

  /// No description provided for @adminPluginUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get adminPluginUninstall;

  /// No description provided for @adminPluginRestartPending.
  ///
  /// In en, this message translates to:
  /// **'Needs a restart'**
  String get adminPluginRestartPending;

  /// No description provided for @adminPluginBroken.
  ///
  /// In en, this message translates to:
  /// **'Not working'**
  String get adminPluginBroken;

  /// No description provided for @adminPluginSuperceded.
  ///
  /// In en, this message translates to:
  /// **'Superseded'**
  String get adminPluginSuperceded;

  /// No description provided for @adminPluginUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported'**
  String get adminPluginUnsupported;

  /// No description provided for @adminPluginChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} updated. Some changes need a restart.'**
  String adminPluginChanged(String name);

  /// No description provided for @adminPluginRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} uninstalled.'**
  String adminPluginRemoved(String name);

  /// No description provided for @adminUninstallPluginQuestion.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {name}?'**
  String adminUninstallPluginQuestion(String name);

  /// No description provided for @adminUninstallPluginBody.
  ///
  /// In en, this message translates to:
  /// **'Its settings stay on the server, but it stops working until it is installed again.'**
  String get adminUninstallPluginBody;

  /// No description provided for @adminRename.
  ///
  /// In en, this message translates to:
  /// **'Rename server'**
  String get adminRename;

  /// No description provided for @adminRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get adminRenameHint;

  /// No description provided for @adminRenamed.
  ///
  /// In en, this message translates to:
  /// **'Server renamed.'**
  String get adminRenamed;

  /// No description provided for @renameServerLocal.
  ///
  /// In en, this message translates to:
  /// **'Only on this device. The server and its other apps keep the name it has. Leave empty to use the server\'s.'**
  String get renameServerLocal;

  /// No description provided for @adminRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart server'**
  String get adminRestart;

  /// No description provided for @adminRestartQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restart {name}?'**
  String adminRestartQuestion(String name);

  /// No description provided for @adminRestartBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone watching is cut off. The server comes back on its own.'**
  String get adminRestartBody;

  /// No description provided for @adminRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restart requested.'**
  String get adminRestarting;

  /// No description provided for @adminShutdown.
  ///
  /// In en, this message translates to:
  /// **'Shut down server'**
  String get adminShutdown;

  /// No description provided for @adminShutdownQuestion.
  ///
  /// In en, this message translates to:
  /// **'Shut down {name}?'**
  String adminShutdownQuestion(String name);

  /// No description provided for @adminShutdownBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone watching is cut off, and nothing here can start it again - someone has to start it at the machine.'**
  String get adminShutdownBody;

  /// No description provided for @adminShuttingDown.
  ///
  /// In en, this message translates to:
  /// **'Shutdown requested.'**
  String get adminShuttingDown;

  /// No description provided for @adminCannotRestart.
  ///
  /// In en, this message translates to:
  /// **'This server cannot restart itself.'**
  String get adminCannotRestart;

  /// No description provided for @adminUserYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get adminUserYou;

  /// No description provided for @adminAddUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get adminAddUser;

  /// No description provided for @adminNewUserTitle.
  ///
  /// In en, this message translates to:
  /// **'New user'**
  String get adminNewUserTitle;

  /// No description provided for @adminUserNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminUserNameLabel;

  /// No description provided for @adminPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get adminPasswordOptional;

  /// No description provided for @adminCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCreate;

  /// No description provided for @adminUserCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} created.'**
  String adminUserCreated(String name);

  /// No description provided for @adminSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get adminSetPassword;

  /// No description provided for @adminNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get adminNewPassword;

  /// No description provided for @adminConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get adminConfirmPassword;

  /// No description provided for @adminPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get adminPasswordMismatch;

  /// No description provided for @adminPasswordEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to remove the password. Every device signed in to this account is signed out.'**
  String get adminPasswordEmptyHint;

  /// No description provided for @adminPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed for {name}.'**
  String adminPasswordChanged(String name);

  /// No description provided for @adminPasswordRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} no longer has a password.'**
  String adminPasswordRemoved(String name);

  /// No description provided for @adminHasPassword.
  ///
  /// In en, this message translates to:
  /// **'Has a password'**
  String get adminHasPassword;

  /// No description provided for @adminNoPassword.
  ///
  /// In en, this message translates to:
  /// **'No password'**
  String get adminNoPassword;

  /// No description provided for @adminDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get adminDeleteUser;

  /// No description provided for @adminDeleteUserQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String adminDeleteUserQuestion(String name);

  /// No description provided for @adminDeleteUserBody.
  ///
  /// In en, this message translates to:
  /// **'The account, its playlists and its watch history are removed, and every device it is signed in on is signed out. This cannot be undone.'**
  String get adminDeleteUserBody;

  /// No description provided for @adminUserDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String adminUserDeleted(String name);

  /// No description provided for @adminUserSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes to {name} saved.'**
  String adminUserSaved(String name);

  /// No description provided for @adminUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'The server did not describe this account.'**
  String get adminUserNotFound;

  /// No description provided for @adminSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminSectionAccount;

  /// No description provided for @adminPolicyAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Can manage the server and every account on it.'**
  String get adminPolicyAdminBody;

  /// No description provided for @adminPolicyDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Cannot sign in.'**
  String get adminPolicyDisabledBody;

  /// No description provided for @adminPolicyAdminNotDisabled.
  ///
  /// In en, this message translates to:
  /// **'An administrator cannot be disabled.'**
  String get adminPolicyAdminNotDisabled;

  /// No description provided for @adminPolicyHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden from the sign-in screen'**
  String get adminPolicyHidden;

  /// No description provided for @adminPolicySelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot change this for your own account.'**
  String get adminPolicySelf;

  /// No description provided for @adminSectionLibraries.
  ///
  /// In en, this message translates to:
  /// **'Library access'**
  String get adminSectionLibraries;

  /// No description provided for @adminPolicyAllLibraries.
  ///
  /// In en, this message translates to:
  /// **'All libraries'**
  String get adminPolicyAllLibraries;

  /// No description provided for @adminPolicyAllLibrariesBody.
  ///
  /// In en, this message translates to:
  /// **'Including libraries added later.'**
  String get adminPolicyAllLibrariesBody;

  /// No description provided for @adminNoLibraries.
  ///
  /// In en, this message translates to:
  /// **'This server has no libraries.'**
  String get adminNoLibraries;

  /// No description provided for @adminSectionPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get adminSectionPlayback;

  /// No description provided for @adminPolicyPlayback.
  ///
  /// In en, this message translates to:
  /// **'Allow playback'**
  String get adminPolicyPlayback;

  /// No description provided for @adminPolicyVideoTranscoding.
  ///
  /// In en, this message translates to:
  /// **'Allow video transcoding'**
  String get adminPolicyVideoTranscoding;

  /// No description provided for @adminPolicyAudioTranscoding.
  ///
  /// In en, this message translates to:
  /// **'Allow audio transcoding'**
  String get adminPolicyAudioTranscoding;

  /// No description provided for @adminPolicyRemuxing.
  ///
  /// In en, this message translates to:
  /// **'Allow remuxing'**
  String get adminPolicyRemuxing;

  /// No description provided for @adminPolicyRemoteAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow remote access'**
  String get adminPolicyRemoteAccess;

  /// No description provided for @adminPolicyRemoteAccessBody.
  ///
  /// In en, this message translates to:
  /// **'From outside the server\'s network.'**
  String get adminPolicyRemoteAccessBody;

  /// No description provided for @adminPolicyBitrate.
  ///
  /// In en, this message translates to:
  /// **'Remote bitrate limit'**
  String get adminPolicyBitrate;

  /// No description provided for @adminPolicySessions.
  ///
  /// In en, this message translates to:
  /// **'Maximum active sessions'**
  String get adminPolicySessions;

  /// No description provided for @adminNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get adminNoLimit;

  /// No description provided for @adminMbps.
  ///
  /// In en, this message translates to:
  /// **'{value} Mbps'**
  String adminMbps(String value);

  /// No description provided for @adminSectionContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get adminSectionContent;

  /// No description provided for @adminPolicyDownloads.
  ///
  /// In en, this message translates to:
  /// **'Allow downloads'**
  String get adminPolicyDownloads;

  /// No description provided for @adminPolicyDeletion.
  ///
  /// In en, this message translates to:
  /// **'Allow deleting media'**
  String get adminPolicyDeletion;

  /// No description provided for @adminPolicyCollections.
  ///
  /// In en, this message translates to:
  /// **'Allow managing collections'**
  String get adminPolicyCollections;

  /// No description provided for @adminSectionParental.
  ///
  /// In en, this message translates to:
  /// **'Parental control'**
  String get adminSectionParental;

  /// No description provided for @adminPolicyMaxRating.
  ///
  /// In en, this message translates to:
  /// **'Maximum allowed rating'**
  String get adminPolicyMaxRating;

  /// No description provided for @adminRatingScore.
  ///
  /// In en, this message translates to:
  /// **'Rating {score}'**
  String adminRatingScore(int score);

  /// No description provided for @adminDiscardQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get adminDiscardQuestion;

  /// No description provided for @adminDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'What you changed here has not been saved.'**
  String get adminDiscardBody;

  /// No description provided for @adminDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get adminDiscard;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get actionRun;

  /// No description provided for @tabSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get tabSuggestions;

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @tabGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get tabGenres;

  /// No description provided for @noUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this library is scheduled to air yet.'**
  String get noUpcoming;

  /// No description provided for @noGenres.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this library is filed under a genre.'**
  String get noGenres;

  /// No description provided for @upcomingUndated.
  ///
  /// In en, this message translates to:
  /// **'Date not announced'**
  String get upcomingUndated;

  /// No description provided for @tabCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get tabCollections;

  /// No description provided for @tabPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get tabPlaylists;

  /// No description provided for @noCollections.
  ///
  /// In en, this message translates to:
  /// **'No collections draw on this library.'**
  String get noCollections;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists on this server yet.'**
  String get noPlaylists;

  /// No description provided for @noSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Nothing to suggest yet — watch something and come back.'**
  String get noSuggestions;

  /// No description provided for @emptyPlaylist.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty.'**
  String get emptyPlaylist;

  /// No description provided for @becauseYouWatched.
  ///
  /// In en, this message translates to:
  /// **'Because you watched {title}'**
  String becauseYouWatched(String title);

  /// No description provided for @becauseYouLike.
  ///
  /// In en, this message translates to:
  /// **'Because you like {title}'**
  String becauseYouLike(String title);

  /// No description provided for @directedBy.
  ///
  /// In en, this message translates to:
  /// **'Directed by {name}'**
  String directedBy(String name);

  /// No description provided for @starring.
  ///
  /// In en, this message translates to:
  /// **'Starring {name}'**
  String starring(String name);

  /// No description provided for @suggestedForYou.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get suggestedForYou;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemCount(int count);

  /// No description provided for @itemCountAtLeast.
  ///
  /// In en, this message translates to:
  /// **'{count}+ items'**
  String itemCountAtLeast(int count);

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

  /// No description provided for @searchMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get searchMovies;

  /// No description provided for @searchShows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get searchShows;

  /// No description provided for @searchEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get searchEpisodes;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeople;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearHistory;

  /// No description provided for @removeFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get removeFromHistory;

  /// No description provided for @whereToLook.
  ///
  /// In en, this message translates to:
  /// **'Where to look'**
  String get whereToLook;

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

  /// No description provided for @autoConnectServer.
  ///
  /// In en, this message translates to:
  /// **'Open the last server on launch'**
  String get autoConnectServer;

  /// No description provided for @autoConnectServerSub.
  ///
  /// In en, this message translates to:
  /// **'Skip the server list and sign in to the server used most recently'**
  String get autoConnectServerSub;

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

  /// No description provided for @decoder.
  ///
  /// In en, this message translates to:
  /// **'Decoder'**
  String get decoder;

  /// No description provided for @hardwareDecodingAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (safe)'**
  String get hardwareDecodingAuto;

  /// No description provided for @hardwareDecodingAutoSub.
  ///
  /// In en, this message translates to:
  /// **'Hardware for the codecs mpv trusts, software for the rest'**
  String get hardwareDecodingAutoSub;

  /// No description provided for @hardwareDecodingPrefer.
  ///
  /// In en, this message translates to:
  /// **'Prefer hardware'**
  String get hardwareDecodingPrefer;

  /// No description provided for @hardwareDecodingPreferSub.
  ///
  /// In en, this message translates to:
  /// **'Every codec the GPU claims. Fastest, and the one that can show a broken picture'**
  String get hardwareDecodingPreferSub;

  /// No description provided for @hardwareDecodingSoftware.
  ///
  /// In en, this message translates to:
  /// **'Software only'**
  String get hardwareDecodingSoftware;

  /// No description provided for @hardwareDecodingSoftwareSub.
  ///
  /// In en, this message translates to:
  /// **'The CPU decodes everything. Heavier on the battery, but it plays what hardware gets wrong'**
  String get hardwareDecodingSoftwareSub;

  /// No description provided for @decodingNow.
  ///
  /// In en, this message translates to:
  /// **'Decoding now: {decoder}'**
  String decodingNow(String decoder);

  /// No description provided for @decodingSoftware.
  ///
  /// In en, this message translates to:
  /// **'software'**
  String get decodingSoftware;

  /// No description provided for @hardwareDecoding.
  ///
  /// In en, this message translates to:
  /// **'Hardware decoding'**
  String get hardwareDecoding;

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

  /// No description provided for @serverSegments.
  ///
  /// In en, this message translates to:
  /// **'Server segments'**
  String get serverSegments;

  /// No description provided for @serverSegmentsSub.
  ///
  /// In en, this message translates to:
  /// **'What to do when a Jellyfin server marks part of an episode'**
  String get serverSegmentsSub;

  /// No description provided for @segmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Opening titles'**
  String get segmentIntro;

  /// No description provided for @segmentOutro.
  ///
  /// In en, this message translates to:
  /// **'Closing credits'**
  String get segmentOutro;

  /// No description provided for @segmentRecap.
  ///
  /// In en, this message translates to:
  /// **'Recap'**
  String get segmentRecap;

  /// No description provided for @segmentPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get segmentPreview;

  /// No description provided for @segmentCommercial.
  ///
  /// In en, this message translates to:
  /// **'Advert'**
  String get segmentCommercial;

  /// No description provided for @segmentActionNothing.
  ///
  /// In en, this message translates to:
  /// **'Do nothing'**
  String get segmentActionNothing;

  /// No description provided for @segmentActionAsk.
  ///
  /// In en, this message translates to:
  /// **'Offer to skip'**
  String get segmentActionAsk;

  /// No description provided for @segmentActionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip automatically'**
  String get segmentActionSkip;

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

  /// No description provided for @autoUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get autoUpdateCheck;

  /// No description provided for @autoUpdateCheckSub.
  ///
  /// In en, this message translates to:
  /// **'Once a day, from GitHub. Nothing about you is sent'**
  String get autoUpdateCheckSub;

  /// No description provided for @updateOfferBody.
  ///
  /// In en, this message translates to:
  /// **'A newer version of mPlayer is ready to install.'**
  String get updateOfferBody;

  /// No description provided for @updateOfferBodySized.
  ///
  /// In en, this message translates to:
  /// **'A newer version of mPlayer is ready to install ({size} MB).'**
  String updateOfferBodySized(String size);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkip;

  /// No description provided for @updateOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open release page'**
  String get updateOpenPage;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the update…'**
  String get updateDownloading;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing — mPlayer will restart.'**
  String get updateInstalling;

  /// No description provided for @updateInstallerOpened.
  ///
  /// In en, this message translates to:
  /// **'The installer is open. Confirm there to finish updating.'**
  String get updateInstallerOpened;

  /// No description provided for @updateNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow mPlayer to install apps in the settings page that just opened, then come back and try again.'**
  String get updateNeedsPermission;

  /// No description provided for @updateNotWritable.
  ///
  /// In en, this message translates to:
  /// **'mPlayer cannot write to the folder it is installed in, so it cannot update itself. Download the new version from the release page instead.'**
  String get updateNotWritable;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'The update could not be installed. You can download it from the release page instead.'**
  String get updateFailed;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download did not finish. Check the connection and try again, or download it from the release page.'**
  String get updateDownloadFailed;

  /// No description provided for @updateTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateTryAgain;

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
  /// **'mPlayer is not affiliated with, endorsed by, or sponsored by the Jellyfin project.'**
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

  /// No description provided for @audioAndSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Audio & subtitles'**
  String get audioAndSubtitles;

  /// No description provided for @tracksValue.
  ///
  /// In en, this message translates to:
  /// **'Audio: {audio} · Subtitles: {subtitles}'**
  String tracksValue(String audio, String subtitles);

  /// No description provided for @quickBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get quickBackground;

  /// No description provided for @quickSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get quickSpeed;

  /// No description provided for @quickScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get quickScreenshot;

  /// No description provided for @noTracks.
  ///
  /// In en, this message translates to:
  /// **'None in this file'**
  String get noTracks;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

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

  /// No description provided for @previousChapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get previousChapter;

  /// No description provided for @nextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get nextChapter;

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

  /// No description provided for @skipCredits.
  ///
  /// In en, this message translates to:
  /// **'Skip credits'**
  String get skipCredits;

  /// No description provided for @skipRecap.
  ///
  /// In en, this message translates to:
  /// **'Skip recap'**
  String get skipRecap;

  /// No description provided for @skipPreview.
  ///
  /// In en, this message translates to:
  /// **'Skip preview'**
  String get skipPreview;

  /// No description provided for @skipAdvert.
  ///
  /// In en, this message translates to:
  /// **'Skip advert'**
  String get skipAdvert;

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

  /// No description provided for @remoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote control'**
  String get remoteTitle;

  /// No description provided for @remoteSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Control mPlayer on a computer or TV from this phone'**
  String get remoteSettingsSub;

  /// No description provided for @remoteSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for mPlayer on this network…'**
  String get remoteSearching;

  /// No description provided for @remoteNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No computer or TV found yet. Open mPlayer on it and make sure both are on the same network.'**
  String get remoteNoDevices;

  /// No description provided for @remoteConnectByAddress.
  ///
  /// In en, this message translates to:
  /// **'Connect by address'**
  String get remoteConnectByAddress;

  /// No description provided for @remoteAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get remoteAddressLabel;

  /// No description provided for @remoteUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach that device.'**
  String get remoteUnreachable;

  /// No description provided for @remoteConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}…'**
  String remoteConnecting(String name);

  /// No description provided for @remotePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair with {name}'**
  String remotePinTitle(String name);

  /// No description provided for @remotePinBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on {name}.'**
  String remotePinBody(String name);

  /// No description provided for @remotePinWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. {count} tries left.'**
  String remotePinWrong(int count);

  /// No description provided for @remotePinLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get remotePinLabel;

  /// No description provided for @remoteDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get remoteDisconnect;

  /// No description provided for @remoteNothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing on {name}.'**
  String remoteNothingPlaying(String name);

  /// No description provided for @remoteNothingPlayingHint.
  ///
  /// In en, this message translates to:
  /// **'Pick something in the library and press Play — it will play on {name}.'**
  String remoteNothingPlayingHint(String name);

  /// No description provided for @remoteControlling.
  ///
  /// In en, this message translates to:
  /// **'Controlling {name}'**
  String remoteControlling(String name);

  /// No description provided for @remoteVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get remoteVolume;

  /// No description provided for @remoteStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get remoteStop;

  /// No description provided for @remotePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get remotePrevious;

  /// No description provided for @remoteSentTo.
  ///
  /// In en, this message translates to:
  /// **'Playing on {name}'**
  String remoteSentTo(String name);

  /// No description provided for @remotePlayHere.
  ///
  /// In en, this message translates to:
  /// **'Play here'**
  String get remotePlayHere;

  /// No description provided for @remoteWrongServer.
  ///
  /// In en, this message translates to:
  /// **'{name} is signed in to a different server.'**
  String remoteWrongServer(String name);

  /// No description provided for @remoteLocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is locked or signed out. Open it there first.'**
  String remoteLocked(String name);

  /// No description provided for @remoteVersion.
  ///
  /// In en, this message translates to:
  /// **'{name} runs a different version of mPlayer. Update both.'**
  String remoteVersion(String name);

  /// No description provided for @remotePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play that on {name}.'**
  String remotePlayFailed(String name);

  /// No description provided for @remoteReceiverSetting.
  ///
  /// In en, this message translates to:
  /// **'Allow phone remote'**
  String get remoteReceiverSetting;

  /// No description provided for @remoteReceiverSettingSub.
  ///
  /// In en, this message translates to:
  /// **'mPlayer on a phone on this network can control playback here. A new phone has to enter the code shown on screen.'**
  String get remoteReceiverSettingSub;

  /// No description provided for @remoteForgetPhones.
  ///
  /// In en, this message translates to:
  /// **'Forget paired phones'**
  String get remoteForgetPhones;

  /// No description provided for @remoteForgetPhonesSub.
  ///
  /// In en, this message translates to:
  /// **'Every phone will need a code again'**
  String get remoteForgetPhonesSub;

  /// No description provided for @remotePhonesForgotten.
  ///
  /// In en, this message translates to:
  /// **'Paired phones forgotten.'**
  String get remotePhonesForgotten;

  /// No description provided for @remotePairingTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to control mPlayer'**
  String remotePairingTitle(String name);

  /// No description provided for @remotePairingBody.
  ///
  /// In en, this message translates to:
  /// **'Enter this code on the phone'**
  String get remotePairingBody;

  /// No description provided for @remoteControlledBy.
  ///
  /// In en, this message translates to:
  /// **'Controlled by {name}'**
  String remoteControlledBy(String name);

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

  /// No description provided for @nextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get nextEpisode;

  /// No description provided for @nextVideo.
  ///
  /// In en, this message translates to:
  /// **'Next video'**
  String get nextVideo;

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

  /// No description provided for @loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loop;

  /// No description provided for @loopOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat this video'**
  String get loopOne;

  /// No description provided for @loopAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat the folder'**
  String get loopAll;

  /// No description provided for @qualityValue.
  ///
  /// In en, this message translates to:
  /// **'Quality: {label}'**
  String qualityValue(String label);

  /// No description provided for @screenshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Screenshot saved to {folder}'**
  String screenshotSaved(String folder);

  /// No description provided for @screenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not take a screenshot of this frame'**
  String get screenshotFailed;

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
  /// **'Asks GitHub. Nothing about you or the device is sent'**
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
  /// **'Update checks go to GitHub only'**
  String get privacyUpdates;

  /// No description provided for @privacyUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'While \"Check for updates automatically\" is on, mPlayer asks the GitHub releases API once a day whether a newer build exists — one anonymous request, with no identifier. Turn it off in Settings → General and checks happen only when you press \"Check for updates\". Updates download from the same release page.'**
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

  /// No description provided for @addToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get addToCollection;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @addedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String addedToCollection(String name);

  /// No description provided for @selectItems.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectItems;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @shuffleItems.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffleItems;

  /// No description provided for @playAllFromHere.
  ///
  /// In en, this message translates to:
  /// **'Play all from here'**
  String get playAllFromHere;

  /// No description provided for @endsAt.
  ///
  /// In en, this message translates to:
  /// **'Ends at {time}'**
  String endsAt(String time);

  /// No description provided for @videoTrack.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoTrack;

  /// No description provided for @firstAired.
  ///
  /// In en, this message translates to:
  /// **'First aired'**
  String get firstAired;

  /// No description provided for @externalLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get externalLinks;

  /// No description provided for @episodeLength.
  ///
  /// In en, this message translates to:
  /// **'Episode length'**
  String get episodeLength;

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

  /// No description provided for @addServerSub.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Jellyfin server to browse and play its libraries.'**
  String get addServerSub;

  /// No description provided for @addServerStepServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get addServerStepServer;

  /// No description provided for @addServerStepAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get addServerStepAccount;

  /// No description provided for @quickConnectShort.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect'**
  String get quickConnectShort;

  /// No description provided for @quickConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect'**
  String get quickConnectTitle;

  /// No description provided for @quickConnectRowSub.
  ///
  /// In en, this message translates to:
  /// **'Sign in another device with the code it shows'**
  String get quickConnectRowSub;

  /// No description provided for @quickConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on the device you want to sign in. It will be signed in as you.'**
  String get quickConnectBody;

  /// No description provided for @quickConnectCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get quickConnectCode;

  /// No description provided for @quickConnectApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get quickConnectApprove;

  /// No description provided for @quickConnectApproved.
  ///
  /// In en, this message translates to:
  /// **'Device signed in.'**
  String get quickConnectApproved;

  /// No description provided for @quickConnectUnknownCode.
  ///
  /// In en, this message translates to:
  /// **'No device is waiting with that code. Check it, or get a new one — codes expire after a few minutes.'**
  String get quickConnectUnknownCode;

  /// No description provided for @quickConnectRefused.
  ///
  /// In en, this message translates to:
  /// **'This server did not allow it. Quick Connect may be turned off in its settings.'**
  String get quickConnectRefused;

  /// No description provided for @quickConnectSteps.
  ///
  /// In en, this message translates to:
  /// **'Open Settings → Quick Connect on any device that is already signed in, and enter the code there. No password is typed here.'**
  String get quickConnectSteps;

  /// No description provided for @quickConnectOff.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect is turned off on this server. An administrator can turn it on in the dashboard.'**
  String get quickConnectOff;

  /// No description provided for @quickConnectNewCode.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get quickConnectNewCode;

  /// No description provided for @quickConnectExpired.
  ///
  /// In en, this message translates to:
  /// **'The code expired before it was approved. Get a new one and try again.'**
  String get quickConnectExpired;

  /// No description provided for @quickConnectRequesting.
  ///
  /// In en, this message translates to:
  /// **'Getting a code…'**
  String get quickConnectRequesting;

  /// No description provided for @quickConnectWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval · {time} left'**
  String quickConnectWaiting(String time);

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @pinLockTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN lock'**
  String get pinLockTitle;

  /// No description provided for @pinLockOn.
  ///
  /// In en, this message translates to:
  /// **'On — asked each time this server is opened here'**
  String get pinLockOn;

  /// No description provided for @pinLockOff.
  ///
  /// In en, this message translates to:
  /// **'Off — anyone with this device can open this server'**
  String get pinLockOff;

  /// No description provided for @pinEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinEnterTitle;

  /// No description provided for @pinEnterBody.
  ///
  /// In en, this message translates to:
  /// **'This server is locked with a PIN on this device.'**
  String get pinEnterBody;

  /// No description provided for @pinUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlock;

  /// No description provided for @pinWrong.
  ///
  /// In en, this message translates to:
  /// **'That PIN is not right.'**
  String get pinWrong;

  /// No description provided for @pinPaused.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Try again in {seconds} s.'**
  String pinPaused(String seconds);

  /// No description provided for @pinSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get pinSetTitle;

  /// No description provided for @pinSetBody.
  ///
  /// In en, this message translates to:
  /// **'4 to 8 digits. It is asked for each time this server is opened on this device, and is not shared with the server.'**
  String get pinSetBody;

  /// No description provided for @pinNew.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get pinNew;

  /// No description provided for @pinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirm;

  /// No description provided for @pinLength.
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 8 digits.'**
  String get pinLength;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two PINs are not the same.'**
  String get pinMismatch;

  /// No description provided for @pinCurrent.
  ///
  /// In en, this message translates to:
  /// **'Enter the current PIN'**
  String get pinCurrent;

  /// No description provided for @pinChange.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get pinChange;

  /// No description provided for @pinRemove.
  ///
  /// In en, this message translates to:
  /// **'Turn off PIN'**
  String get pinRemove;

  /// No description provided for @pinSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved.'**
  String get pinSaved;

  /// No description provided for @pinRemoved.
  ///
  /// In en, this message translates to:
  /// **'PIN turned off.'**
  String get pinRemoved;

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

  /// No description provided for @viewOptions.
  ///
  /// In en, this message translates to:
  /// **'View options'**
  String get viewOptions;

  /// No description provided for @groupByCollection.
  ///
  /// In en, this message translates to:
  /// **'Group by collection'**
  String get groupByCollection;

  /// No description provided for @groupByCollectionSub.
  ///
  /// In en, this message translates to:
  /// **'One poster for each collection instead of each film in it. Not while filtering'**
  String get groupByCollectionSub;

  /// No description provided for @startTab.
  ///
  /// In en, this message translates to:
  /// **'Tab when opening the app'**
  String get startTab;

  /// No description provided for @rememberLastTab.
  ///
  /// In en, this message translates to:
  /// **'Remember last tab'**
  String get rememberLastTab;

  /// No description provided for @rememberLastTabSub.
  ///
  /// In en, this message translates to:
  /// **'Open on the tab you were on when the app closed'**
  String get rememberLastTabSub;

  /// No description provided for @showOnCards.
  ///
  /// In en, this message translates to:
  /// **'Show on cards'**
  String get showOnCards;

  /// No description provided for @cardYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get cardYear;

  /// No description provided for @cardCount.
  ///
  /// In en, this message translates to:
  /// **'Number of items'**
  String get cardCount;

  /// No description provided for @cardCountSub.
  ///
  /// In en, this message translates to:
  /// **'Episodes in a series, films in a collection'**
  String get cardCountSub;

  /// No description provided for @cardStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cardStatus;

  /// No description provided for @cardStatusSub.
  ///
  /// In en, this message translates to:
  /// **'Whether a series is still running'**
  String get cardStatusSub;

  /// No description provided for @episodeCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} ep'**
  String episodeCountShort(int count);

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
  /// **'Continue · {time}'**
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

  /// No description provided for @sortAndFilter.
  ///
  /// In en, this message translates to:
  /// **'Sort & filter'**
  String get sortAndFilter;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @sortCommunityRating.
  ///
  /// In en, this message translates to:
  /// **'Community rating'**
  String get sortCommunityRating;

  /// No description provided for @sortEpisodeAdded.
  ///
  /// In en, this message translates to:
  /// **'Latest episode added'**
  String get sortEpisodeAdded;

  /// No description provided for @sortParentalRating.
  ///
  /// In en, this message translates to:
  /// **'Parental rating'**
  String get sortParentalRating;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get filterFeatures;

  /// No description provided for @filterGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get filterGenres;

  /// No description provided for @filterParentalRatings.
  ///
  /// In en, this message translates to:
  /// **'Parental ratings'**
  String get filterParentalRatings;

  /// No description provided for @filterTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get filterTags;

  /// No description provided for @filterYears.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get filterYears;

  /// No description provided for @filterPlayed.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get filterPlayed;

  /// No description provided for @filterUnplayed.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get filterUnplayed;

  /// No description provided for @filterFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get filterFavourite;

  /// No description provided for @filterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get filterInProgress;

  /// No description provided for @featureTrailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get featureTrailer;

  /// No description provided for @featureExtras.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get featureExtras;

  /// No description provided for @featureThemeSong.
  ///
  /// In en, this message translates to:
  /// **'Theme song'**
  String get featureThemeSong;

  /// No description provided for @featureThemeVideo.
  ///
  /// In en, this message translates to:
  /// **'Theme video'**
  String get featureThemeVideo;

  /// No description provided for @filterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get filterApply;

  /// No description provided for @filterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// No description provided for @nothingToFilterBy.
  ///
  /// In en, this message translates to:
  /// **'This library holds nothing else to filter by.'**
  String get nothingToFilterBy;

  /// No description provided for @heroResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get heroResume;

  /// No description provided for @heroDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get heroDetails;

  /// No description provided for @downloadsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Download a film or an episode from its page to watch it here without a connection.'**
  String get downloadsEmptyHint;

  /// No description provided for @addedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Added to downloads'**
  String get addedToDownloads;

  /// No description provided for @downloadQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadQueued;

  /// No description provided for @downloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading · {percent}%'**
  String downloadingPercent(int percent);

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadPaused;

  /// No description provided for @resumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get resumeDownload;

  /// No description provided for @retryDownload.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryDownload;

  /// No description provided for @removeDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get removeDownload;

  /// No description provided for @removeDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this download?'**
  String get removeDownloadTitle;

  /// No description provided for @removeDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'{title} will no longer be available offline.'**
  String removeDownloadBody(String title);

  /// No description provided for @downloadAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Download {count} episodes?'**
  String downloadAllTitle(int count);

  /// No description provided for @downloadAllBody.
  ///
  /// In en, this message translates to:
  /// **'They are saved one at a time, in the original quality, and can take a lot of space.'**
  String get downloadAllBody;

  /// No description provided for @allDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Every episode is already downloaded'**
  String get allDownloaded;

  /// No description provided for @downloadsInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get downloadsInProgress;

  /// No description provided for @downloadsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadsCompleted;

  /// No description provided for @downloadsMovies.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get downloadsMovies;

  /// No description provided for @downloadSizeOf.
  ///
  /// In en, this message translates to:
  /// **'{received} of {total}'**
  String downloadSizeOf(String received, String total);

  /// No description provided for @downloadWaitingForServer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the server to sign in'**
  String get downloadWaitingForServer;

  /// No description provided for @downloadsUsed.
  ///
  /// In en, this message translates to:
  /// **'{size} on this device'**
  String downloadsUsed(String size);

  /// No description provided for @watchDownloads.
  ///
  /// In en, this message translates to:
  /// **'Watch downloads'**
  String get watchDownloads;

  /// No description provided for @downloadsQueuedMore.
  ///
  /// In en, this message translates to:
  /// **'{count} more queued'**
  String downloadsQueuedMore(int count);

  /// No description provided for @downloadWaitingForWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get downloadWaitingForWifi;

  /// No description provided for @downloadWaitingForNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection'**
  String get downloadWaitingForNetwork;

  /// No description provided for @downloadSettings.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadSettings;

  /// No description provided for @downloadSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only, storage'**
  String get downloadSettingsSub;

  /// No description provided for @downloadWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi only'**
  String get downloadWifiOnly;

  /// No description provided for @downloadWifiOnlySub.
  ///
  /// In en, this message translates to:
  /// **'Hold the queue on mobile data and carry on when Wi-Fi is back'**
  String get downloadWifiOnlySub;

  /// No description provided for @downloadRemoveWatched.
  ///
  /// In en, this message translates to:
  /// **'Remove watched downloads'**
  String get downloadRemoveWatched;

  /// No description provided for @downloadRemoveWatchedSub.
  ///
  /// In en, this message translates to:
  /// **'Delete a copy once it has been watched to the end on this device'**
  String get downloadRemoveWatchedSub;

  /// No description provided for @downloadStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get downloadStorage;

  /// No description provided for @downloadRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all downloads'**
  String get downloadRemoveAll;

  /// No description provided for @downloadRemoveAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove every download?'**
  String get downloadRemoveAllTitle;

  /// No description provided for @downloadRemoveAllBody.
  ///
  /// In en, this message translates to:
  /// **'Everything saved on this device for offline viewing will be deleted.'**
  String get downloadRemoveAllBody;

  /// No description provided for @downloadsNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing is downloaded on this device.'**
  String get downloadsNone;

  /// No description provided for @tabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get tabAlbums;

  /// No description provided for @tabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get tabArtists;

  /// No description provided for @tabSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get tabSongs;

  /// No description provided for @noAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums here.'**
  String get noAlbums;

  /// No description provided for @noArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists here.'**
  String get noArtists;

  /// No description provided for @noSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs here.'**
  String get noSongs;

  /// No description provided for @musicLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this from the server.'**
  String get musicLoadFailed;

  /// No description provided for @sortArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get sortArtist;

  /// No description provided for @discNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc {number}'**
  String discNumber(int number);

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String trackCount(int count);

  /// No description provided for @popularTracks.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popularTracks;

  /// No description provided for @seeAllTracks.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAllTracks;

  /// No description provided for @appearsOn.
  ///
  /// In en, this message translates to:
  /// **'Appears on'**
  String get appearsOn;

  /// No description provided for @similarArtists.
  ///
  /// In en, this message translates to:
  /// **'Similar artists'**
  String get similarArtists;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing else is queued.'**
  String get queueEmpty;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @stopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopPlayback;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat is off'**
  String get repeatOff;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeating this song'**
  String get repeatOne;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeating the queue'**
  String get repeatAll;

  /// No description provided for @playNextInQueue.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNextInQueue;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get addedToQueue;

  /// No description provided for @removeFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @instantMix.
  ///
  /// In en, this message translates to:
  /// **'Instant mix'**
  String get instantMix;

  /// No description provided for @noInstantMix.
  ///
  /// In en, this message translates to:
  /// **'The server has no mix for this.'**
  String get noInstantMix;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;
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
