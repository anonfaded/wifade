; ============================================================================
; WIFADE INSTALLER SCRIPT - Inno Setup
; ============================================================================
; This script creates a Windows installer for Wifade that:
; - Installs the application to Program Files
; - Sets up command-line access via PATH environment variable
; - Creates desktop and start menu shortcuts
; - Includes both Wifade.exe (launcher) and WifadeCore.exe
; ============================================================================

#define MyAppName "Wifade"
#define MyAppVersion "2.0"
#define MyAppPublisher "FadSec Lab"
#define MyAppURL "https://github.com/anonfaded/wifade"
#define MyAppExeName "wifade.exe"
#define MyAppCoreExeName "WifadeCore.exe"
#define MyAppDescription "WiFi Security Testing Tool with Built-in Bruteforcer"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
InfoBeforeFile=
InfoAfterFile=
OutputDir=dist
OutputBaseFilename=WifadeSetup-{#MyAppVersion}
SetupIconFile=img\logo.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDescription}
VersionInfoCopyright=© 2024-2025 faded.dev
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Main application files
Source: "build\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\{#MyAppCoreExeName}"; DestDir: "{app}"; Flags: ignoreversion


; Documentation and support files
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "passwords\*"; DestDir: "{app}\passwords"; Flags: ignoreversion recursesubdirs createallsubdirs

; Icon files
Source: "img\logo.ico"; DestDir: "{app}\img"; Flags: ignoreversion
Source: "img\icon.png"; DestDir: "{app}\img"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; IconFilename: "{app}\img\logo.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; Comment: "Uninstall {#MyAppName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; IconFilename: "{app}\img\logo.ico"; Tasks: desktopicon

[Registry]

; Add application registry entries
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Flags: uninsdeletekey


; [Run] section removed to disable launch button on finish page

[UninstallRun]

[Code]
const
  EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

procedure EnvAddPath(Path: string);
var
  Paths: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
    Paths := '';
  if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then exit;
  if Paths = '' then
    Paths := Path
  else
    Paths := Paths + ';' + Path;
  RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths);
end;

procedure EnvRemovePath(Path: string);
var
  Paths: string;
  P: Integer;
begin
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
  begin
    P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
    if P = 0 then exit;
    Delete(Paths, P - 1, Length(Path) + 1);
    RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths);
  end;
end;
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  // look for the path with leading and trailing semicolon
  // Pos() returns 0 if not found
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    EnvAddPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    EnvRemovePath(ExpandConstant('{app}'));
end;

[Messages]
WelcomeLabel2=This will install [name/ver] on your computer.%n%nWifade is a powerful WiFi security testing tool with built-in bruteforcer capabilities. It provides both interactive and command-line interfaces for network analysis and security testing.%n%nIt is recommended that you close all other applications before continuing.
FinishedLabelNoIcons=Setup has finished installing [name] on your computer.%n%nYou can now use 'wifade' command in any terminal or command prompt to access the tool.
FinishedLabel=Setup has finished installing [name] on your computer.%n%nYou can now use 'wifade' command in any terminal or command prompt to access the tool.

[CustomMessages]
LaunchProgram=Launch %1