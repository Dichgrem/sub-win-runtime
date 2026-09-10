; Inno Setup script - builds a single-file offline installer.
; Build:  ISCC.exe /DINCLUDE_DIRECTX /DINCLUDE_DOTNET installer.iss
; Or via: .\build-installer.ps1 -IncludeDirectX -IncludeDotNet
;
; Requires this file to be saved as UTF-8 **with BOM** (non-ASCII UI strings).

#define AppName "Windows Runtimes Offline"
#define AppVer "2026.09.09"

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

procedure RunOfflineInstall;
var
  Code, Waited, LastDone, IdleTicks: Integer;
  Cur: String;
  Done, Total: Integer;
  Params: String;
  Finished: Boolean;
begin
  ProgressFile := ExpandConstant('{tmp}\runtimes-progress.txt');

  ProgressPage := CreateOutputProgressPage('正在安装运行库', '正在安装系统所需的运行库，请勿关闭窗口。');
  ProgressPage.SetText('准备中...', '');
  ProgressPage.SetProgress(0, 1);
  ProgressPage.Show;
  try
    Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\install-offline.ps1') +
              '" -Quiet -ProgressFile "' + ProgressFile + '"';
#ifdef INCLUDE_DIRECTX
    Params := Params + ' -IncludeDirectX';
#endif
#ifdef INCLUDE_DOTNET
    Params := Params + ' -IncludeDotNet';
#endif

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
