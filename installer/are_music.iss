#define MyAppVersion "2.0.14"
// Absolute paths to ensure ISCC finds files when run from PowerShell
#define ProjectRoot "C:\\Users\\bhosl\\failed1"
#define SourceRelease "C:\\Users\\bhosl\\failed1\\build\\windows\\x64\\runner\\Release"

[Setup]
AppName=ARE Music
AppVersion={#MyAppVersion}
DefaultDirName={pf}\ARE Music
DefaultGroupName=ARE Music
OutputBaseFilename=ARE_Music_Installer_v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
SetupIconFile={#ProjectRoot}\\assets\\images\\icon.ico
OutputDir={#ProjectRoot}\\installer\\release

[Files]
; Copy the built Release folder contents into the installed app directory
Source: "{#SourceRelease}\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ARE Music"; Filename: "{app}\\are_music.exe"
Name: "{group}\Uninstall ARE Music"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\\are_music.exe"; Description: "Launch ARE Music"; Flags: nowait postinstall skipifsilent
