; Instalador de StockPyme para Windows (Inno Setup 6).
; Lo compila GitHub Actions; también puedes abrirlo con Inno Setup en tu PC
; después de "flutter build windows --release".

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{8F2A6C1E-5B7D-4E3A-9C21-7D4B2E9A1F30}
AppName=StockPyme
AppVersion={#AppVersion}
AppVerName=StockPyme {#AppVersion}
AppPublisher=Rivera Systems
AppPublisherURL=https://github.com/Omega-kobra-Ariel-Rivera
DefaultDirName={autopf}\StockPyme
DefaultGroupName=StockPyme
DisableProgramGroupPage=yes
OutputDir=..
OutputBaseFilename=StockPyme-Instalador-v{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\stock_pyme.exe
UninstallDisplayName=StockPyme
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\StockPyme"; Filename: "{app}\stock_pyme.exe"
Name: "{group}\Desinstalar StockPyme"; Filename: "{uninstallexe}"
Name: "{autodesktop}\StockPyme"; Filename: "{app}\stock_pyme.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\stock_pyme.exe"; Description: "{cm:LaunchProgram,StockPyme}"; Flags: nowait postinstall skipifsilent
