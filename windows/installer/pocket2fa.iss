; Inno Setup script for Pocket2FA
[Setup]
AppName=Pocket2FA
AppVersion=0.8.1
DefaultDirName={autopf}\Pocket2FA
DefaultGroupName=Pocket2FA
OutputBaseFilename=Pocket2FA_Installer_Windows_x64
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
AllowNoIcons=yes
UsePreviousAppDir=yes
AppPublisher=gmartin
AppPublisherURL=https://github.com/gmag11/pocket2fa
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\\..\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\Pocket2FA"; Filename: "{app}\\pocket2fa.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\\Pocket2FA"; Filename: "{app}\\pocket2fa.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Dirs]
Name: "{app}"; Permissions: users-full

[Run]
Filename: "{app}\\pocket2fa.exe"; Description: "Launch Pocket2FA"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard();
begin
end;

function IsNonAdminInstallMode: Boolean;
begin
  Result := not IsAdminInstallMode;
end;

function GetInstallModeString(Param: String): String;
begin
  if IsNonAdminInstallMode then
    Result := 'Current User'
  else
    Result := 'All Users';
end;