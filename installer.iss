; Inno Setup script - builds a single-file offline installer (same toolchain as the original bundle)
; Build:  ISCC.exe /DINCLUDE_DIRECTX installer.iss
; Or via: .\build-installer.ps1 -IncludeDirectX

#define AppName "Windows Runtimes Offline"
#define AppVer "2026.09.09"

#ifdef INCLUDE_DIRECTX
  #define ExtraDx " -IncludeDirectX"
#else
  #define ExtraDx ""
#endif
#ifdef INCLUDE_DOTNET
  #define ExtraDn " -IncludeDotNet"
#else
  #define ExtraDn ""
#endif

[Setup]
AppId={{8F3A6E1C-2B4D-4C77-9E51-7A1D3C5B9E42}
AppName={#AppName}
AppVersion={#AppVer}
AppPublisher=windows-runtimes-offline
DefaultDirName={autopf}\WindowsRuntimesOffline
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=dist
OutputBaseFilename=windows-runtimes-offline-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupLogging=yes

[Files]
Source: "payload\*"; DestDir: "{app}\payload"; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "install-offline.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-offline.ps1""{#ExtraDx}{#ExtraDn}"; StatusMsg: "Installing Microsoft runtimes... (this may take a few minutes)"; Flags: waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
