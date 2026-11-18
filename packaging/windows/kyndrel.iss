; Kyndrel installer (task 5.6). Build on Windows with Inno Setup 6:
;   flutter build windows --release
;   iscc /DAppVersion=1.0.0 packaging\windows\kyndrel.iss
; Output: build\installer\Kyndrel-<version>-windows-x64-setup.exe
;
; Installs per user by default (no admin prompt); "Install for all users"
; is offered in the dialog. Registers Kyndrel in "Open with" and in
; Settings > Default apps for video, audio and playlist files without
; taking over existing defaults. Silent update (used by the in-app
; updater): Kyndrel-...-setup.exe /SILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS

#ifndef AppVersion
  #define AppVersion "0.0.1"
#endif
#define AppName "Kyndrel"
#define AppExe "kyndrel.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6F1B8F6E-3C2D-4E8B-9A5F-4B1C7D2E9A10}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Kyndrel contributors
AppPublisherURL=https://github.com/xScropy/kyndrel
AppSupportURL=https://github.com/xScropy/kyndrel/issues
AppUpdatesURL=https://github.com/xScropy/kyndrel/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=..\..\LICENSE
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\..\build\installer
OutputBaseFilename=Kyndrel-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=yes
ChangesAssociations=yes
MinVersion=10.0.17763

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; One ProgID for every media type Kyndrel opens.
Root: HKA; Subkey: "Software\Classes\Kyndrel.Media"; ValueType: string; ValueName: ""; ValueData: "Media file"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Kyndrel.Media"; ValueType: string; ValueName: "FriendlyTypeName"; ValueData: "Media file (Kyndrel)"
Root: HKA; Subkey: "Software\Classes\Kyndrel.Media\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExe},0"
Root: HKA; Subkey: "Software\Classes\Kyndrel.Media\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""
; "Open with" entry and the app's friendly name.
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""
; Settings > Default apps.
Root: HKA; Subkey: "Software\Kyndrel"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Kyndrel\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#AppName}"
Root: HKA; Subkey: "Software\Kyndrel\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Video player built on mpv"
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "{#AppName}"; ValueData: "Software\Kyndrel\Capabilities"; Flags: uninsdeletevalue
; Extensions (generated; keep in sync with linux/kyndrel.desktop and
; macos/Runner/Info.plist).
Root: HKA; Subkey: "Software\Classes\.mp4\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mp4"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mp4"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.m4v\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".m4v"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m4v"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mkv\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mkv"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mkv"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.webm\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".webm"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".webm"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.avi\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".avi"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".avi"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mov\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mov"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mov"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.wmv\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".wmv"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wmv"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.flv\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".flv"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".flv"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mpg\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mpg"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mpg"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mpeg\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mpeg"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mpeg"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.ts\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".ts"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ts"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.m2ts\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".m2ts"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m2ts"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mts\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mts"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mts"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.3gp\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".3gp"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".3gp"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.ogv\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".ogv"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ogv"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.vob\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".vob"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".vob"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.divx\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".divx"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".divx"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mp3\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mp3"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mp3"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.flac\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".flac"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".flac"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.ogg\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".ogg"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ogg"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.opus\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".opus"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".opus"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.m4a\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".m4a"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m4a"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.aac\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".aac"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".aac"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.wav\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".wav"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wav"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.wma\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".wma"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wma"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.mka\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".mka"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mka"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.m3u\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".m3u"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m3u"; ValueData: "Kyndrel.Media"
Root: HKA; Subkey: "Software\Classes\.m3u8\OpenWithProgids"; ValueType: string; ValueName: "Kyndrel.Media"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\kyndrel.exe\SupportedTypes"; ValueType: string; ValueName: ".m3u8"; ValueData: ""
Root: HKA; Subkey: "Software\Kyndrel\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m3u8"; ValueData: "Kyndrel.Media"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
