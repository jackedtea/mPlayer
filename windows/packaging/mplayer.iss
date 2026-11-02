; Inno Setup script for the Windows installer. CI compiles it with
;
;   ISCC /DAppVersion=1.2.0 /DNumericVersion=1.2.0 /DSourceDir=<Release folder>
;        /DOutputDir=<dir> /DOutputBase=<file name without .exe> [/DDev]
;
; Per-user only (PrivilegesRequired=lowest, no override): it installs under
; %LOCALAPPDATA%\Programs, which the in-app updater can write to without
; elevation. A per-machine install in Program Files would leave every update
; behind a UAC prompt the updater cannot answer.
;
; A dev build is a different application to Windows — its own AppId, name
; and folder — so it installs beside a release build instead of over it,
; as the `.canary` application id does on Android.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef NumericVersion
  #define NumericVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif
#ifndef OutputBase
  #define OutputBase "mPlayer-setup"
#endif

#ifdef Dev
  #define AppName "mPlayer (Dev)"
  #define AppIdGuid "{{9AD90D96-80D4-4A0E-A18D-3E2B89501F3F}"
  #define DirName "mPlayer Dev"
#else
  #define AppName "mPlayer"
  ; Never change this: it is how Windows knows a new installer is an
  ; upgrade of the installed app rather than a second copy of it.
  #define AppIdGuid "{{6FC87BAC-15D7-47D1-92F5-D86C665D35AD}"
  #define DirName "mPlayer"
#endif

#define ExeName "mPlayer.exe"

[Setup]
AppId={#AppIdGuid}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=dev.icedtea
AppPublisherURL=https://github.com/jackedtea/mPlayer
AppSupportURL=https://github.com/jackedtea/mPlayer/issues
AppUpdatesURL=https://github.com/jackedtea/mPlayer/releases
VersionInfoVersion={#NumericVersion}
DefaultDirName={autopf}\{#DirName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#ExeName}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Flutter's assets from the version being replaced. Left in place they are
; harmless but never cleaned up, and the folder only grows.
Type: filesandordirs; Name: "{app}\data"

[Files]
; The whole Release folder, not the exe: media_kit's libmpv-2.dll and
; Flutter's runtime sit beside it and it does not start without them.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#ExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Run]
; Skipped when silent: the in-app updater runs the installer that way and
; starts the app again itself.
Filename: "{app}\{#ExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
