; Inno Setup script for TwoFactorAuth
[Setup]
AppName=TwoFactorAuth
AppVersion=0.5.2
DefaultDirName={autopf}\TwoFactorAuth
DefaultGroupName=TwoFactorAuth
OutputBaseFilename=TwoFactorAuth_Installer
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\\..\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\TwoFactorAuth"; Filename: "{app}\\twofauth.exe"; WorkingDir: "{app}"
Name: "{commondesktop}\\TwoFactorAuth"; Filename: "{app}\\twofauth.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\\twofauth.exe"; Description: "Launch TwoFactorAuth"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard();
begin
end;