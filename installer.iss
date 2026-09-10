; Inno Setup script - builds a single-file offline installer with a component picker.
; Build:  ISCC.exe /DINCLUDE_DIRECTX /DINCLUDE_DOTNET installer.iss
; Or via: .\build-installer.ps1            (payload presence is auto-detected)
;
; NOTE: keep this file UTF-8 **with BOM** (non-ASCII UI strings).

#define AppName "Windows Runtimes Offline"
#define AppVer "2026.09.09"

[Setup]
AppId={{8F3A6E1C-2B4D-4C77-9E51-7A1D3C5B9E42}
AppName={#AppName}
AppVersion={#AppVer}
AppPublisher=windows-runtimes-offline
SetupIconFile=assets\app.ico
UninstallDisplayIcon={app}\app.ico
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

[Types]
Name: "full"; Description: "完整安装（全部组件）"
Name: "typical"; Description: "推荐安装（Visual C++ 运行库 + VSTO）"
Name: "custom"; Description: "自定义安装"; Flags: iscustom

[Components]
Name: "vc"; Description: "Visual C++ 运行库 (2005-2022, x86 + x64)"; Types: full typical custom
Name: "vc\v2005"; Description: "VC++ 2005"; Types: full typical custom
Name: "vc\v2008"; Description: "VC++ 2008"; Types: full typical custom
Name: "vc\v2010"; Description: "VC++ 2010"; Types: full typical custom
Name: "vc\v2012"; Description: "VC++ 2012"; Types: full typical custom
Name: "vc\v2013"; Description: "VC++ 2013"; Types: full typical custom
Name: "vc\v2015"; Description: "VC++ 2015-2022 (v14)"; Types: full typical custom
Name: "vsto"; Description: "Visual Studio Tools for Office Runtime 4.0"; Types: full typical custom
#ifdef INCLUDE_DOTNET
Name: "dotnet"; Description: ".NET 运行时 (6 / 8 / 10)"; Types: full
#endif
#ifdef INCLUDE_DIRECTX
Name: "directx"; Description: "legacy DirectX 9/10/11 (June 2010)"; Types: full
#endif

[Files]
Source: "install-offline.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "assets\app.ico"; DestDir: "{app}"; Flags: ignoreversion

Source: "payload\Microsoft.VCRedist.2005.x86\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2005.x86"; Components: vc\v2005; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2005.x64\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2005.x64"; Components: vc\v2005; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2008.x86\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2008.x86"; Components: vc\v2008; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2008.x64\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2008.x64"; Components: vc\v2008; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2010.x86\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2010.x86"; Components: vc\v2010; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2010.x64\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2010.x64"; Components: vc\v2010; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2012.x86\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2012.x86"; Components: vc\v2012; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2012.x64\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2012.x64"; Components: vc\v2012; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2013.x86\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2013.x86"; Components: vc\v2013; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2013.x64\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2013.x64"; Components: vc\v2013; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2015+.x86\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2015+.x86"; Components: vc\v2015; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VCRedist.2015+.x64\*"; DestDir: "{app}\payload\Microsoft.VCRedist.2015+.x64"; Components: vc\v2015; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
Source: "payload\Microsoft.VSTOR\*"; DestDir: "{app}\payload\Microsoft.VSTOR"; Components: vsto; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs

#ifdef INCLUDE_DOTNET
Source: "payload\dotnet\*"; DestDir: "{app}\payload\dotnet"; Components: dotnet; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
#endif
#ifdef INCLUDE_DIRECTX
Source: "payload\DirectX\*"; DestDir: "{app}\payload\DirectX"; Components: directx; Excludes: "*.yaml"; Flags: recursesubdirs createallsubdirs
#endif

[InstallDelete]
Type: filesandordirs; Name: "{app}\payload"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
var
  ProgressPage: TOutputProgressWizardPage;
  ProgressFile: String;
  FailCount: Integer;

function ParseProgress(out Cur: String; out Done: Integer; out Total: Integer): Boolean;
var
  Lines: TArrayOfString;
  I, P: Integer;
  S, Kind, Val: String;
begin
  Result := False;
  Cur := '';
  Done := 0;
  Total := 0;
  FailCount := 0;
  if not FileExists(ProgressFile) then
    Exit;
  if not LoadStringsFromFile(ProgressFile, Lines) then
    Exit;

  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    S := Trim(Lines[I]);
    P := Pos('|', S);
    if P = 0 then
      Continue;

    Kind := Copy(S, 1, P - 1);
    Val := Copy(S, P + 1, Length(S));

    if Kind = 'TOTAL' then
      Total := StrToIntDef(Val, 0)
    else if Kind = 'BEGIN' then
      Cur := Val
    else if Kind = 'DONE' then
      Done := Done + 1
    else if Kind = 'FAIL' then
    begin
      Done := Done + 1;
      FailCount := FailCount + 1;
    end
    else if Kind = 'FINISH' then
      Result := True;
  end;
end;

function AddFolder(const Acc, Folder: String): String;
begin
  if Acc = '' then
    Result := Folder
  else
    Result := Acc + ',' + Folder;
end;

function SelectedFolderList: String;
begin
  Result := '';
  if WizardIsComponentSelected('vc\v2005') then
  begin
    Result := AddFolder(Result, 'Microsoft.VCRedist.2005.x86');
    Result := AddFolder(Result, 'Microsoft.VCRedist.2005.x64');
  end;
  if WizardIsComponentSelected('vc\v2008') then
  begin
    Result := AddFolder(Result, 'Microsoft.VCRedist.2008.x86');
    Result := AddFolder(Result, 'Microsoft.VCRedist.2008.x64');
  end;
  if WizardIsComponentSelected('vc\v2010') then
  begin
    Result := AddFolder(Result, 'Microsoft.VCRedist.2010.x86');
    Result := AddFolder(Result, 'Microsoft.VCRedist.2010.x64');
  end;
  if WizardIsComponentSelected('vc\v2012') then
  begin
    Result := AddFolder(Result, 'Microsoft.VCRedist.2012.x86');
    Result := AddFolder(Result, 'Microsoft.VCRedist.2012.x64');
  end;
  if WizardIsComponentSelected('vc\v2013') then
  begin
    Result := AddFolder(Result, 'Microsoft.VCRedist.2013.x86');
    Result := AddFolder(Result, 'Microsoft.VCRedist.2013.x64');
  end;
  if WizardIsComponentSelected('vc\v2015') then
  begin
    Result := AddFolder(Result, 'Microsoft.VCRedist.2015+.x86');
    Result := AddFolder(Result, 'Microsoft.VCRedist.2015+.x64');
  end;
  if WizardIsComponentSelected('vsto') then
    Result := AddFolder(Result, 'Microsoft.VSTOR');
#ifdef INCLUDE_DOTNET
  if WizardIsComponentSelected('dotnet') then
    Result := AddFolder(Result, 'dotnet');
#endif
#ifdef INCLUDE_DIRECTX
  if WizardIsComponentSelected('directx') then
    Result := AddFolder(Result, 'DirectX');
#endif
end;

procedure RunOfflineInstall;
var
  Code, Waited, LastDone, IdleTicks: Integer;
  Cur: String;
  Done, Total: Integer;
  Params: String;
  Finished: Boolean;
begin
  ProgressFile := ExpandConstant('{tmp}\runtimes-progress.txt');

  ProgressPage := CreateOutputProgressPage('正在安装运行库', '正在安装所选组件，请勿关闭窗口。');
  ProgressPage.SetText('准备中...', '');
  ProgressPage.SetProgress(0, 1);
  ProgressPage.Show;
  try
    { -Only: install exactly the components the user checked in the component picker }
    Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\install-offline.ps1') +
              '" -Quiet -ProgressFile "' + ProgressFile + '" -Only "' + SelectedFolderList + '"';

    if not Exec('powershell.exe', Params, '', SW_HIDE, ewNoWait, Code) then
    begin
      MsgBox('无法启动安装程序 (powershell.exe)。', mbError, MB_OK);
      Exit;
    end;

    Waited := 0;
    LastDone := -1;
    IdleTicks := 0;
    repeat
      Sleep(250);
      Finished := ParseProgress(Cur, Done, Total);
      if Total > 0 then
        ProgressPage.SetProgress(Done, Total);
      if Cur <> '' then
        ProgressPage.SetText('正在安装：' + Cur, Format('已完成 %d / %d', [Done, Total]));
      if Done <> LastDone then
      begin
        LastDone := Done;
        IdleTicks := 0;
      end
      else
        IdleTicks := IdleTicks + 1;
      Waited := Waited + 250;
    until Finished or (Waited > 7200000) or (IdleTicks > 4800);   { 卡死保护：20 分钟无进展即中断 }
  finally
    ProgressPage.Hide;
  end;

  if FailCount > 0 then
    MsgBox(Format('有 %d 个组件安装失败。'#13#10'详情见安装目录下的 install-offline.log。', [FailCount]), mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    RunOfflineInstall;
end;
