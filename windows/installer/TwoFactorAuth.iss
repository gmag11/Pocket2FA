; Inno Setup script for 2FAuth
[Setup]
AppName=2FAuth
AppVersion=0.5.3
DefaultDirName={autopf}\2FAuth
DefaultGroupName=2FAuth
OutputBaseFilename=2FAuth_Installer
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\\..\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\2FAuth"; Filename: "{app}\\2fauth.exe"; WorkingDir: "{app}"
Name: "{commondesktop}\\2FAuth"; Filename: "{app}\\2fauth.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\\2FAuth.exe"; Description: "Launch 2FAuth"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard();
begin
end;