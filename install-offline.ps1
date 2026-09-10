#requires -Version 5.1
<#
.SYNOPSIS
    Offline runtime installer - installs components from .\payload, no network needed.

.DESCRIPTION
    Silent switches are taken verbatim from the official winget manifests.

    Selection modes (first match wins):
      -Only <folders>   explicit comma-separated payload folders (used by installer.iss,
                        e.g. "Microsoft.VCRedist.2015+.x86,Microsoft.VSTOR,dotnet")
      -FromPayload      install whatever folders exist in .\payload
      (neither)         core 13 components, plus -IncludeDirectX / -IncludeDotNet

    With -ProgressFile, machine-readable progress is appended for the GUI installer:
        TOTAL|<n>  BEGIN|<name>  DONE|<name>  FAIL|<name>  FINISH|<failCount>

.PARAMETER IncludeDirectX
    (legacy mode) also install legacy DirectX.

.PARAMETER IncludeDotNet
    (legacy mode) also install .NET modern runtimes.

.PARAMETER Quiet
    No console output (log file only).

.PARAMETER ProgressFile
    Path the progress lines are appended to (used by installer.iss).

.PARAMETER FromPayload
    Install exactly the components present in .\payload (ignores -IncludeDirectX / -IncludeDotNet).

.PARAMETER Only
    Comma-separated payload folder names to install; "dotnet" expands to all .NET sub-packages,
    "DirectX" to the legacy DirectX redist.
#>
[CmdletBinding()]
param(
    [switch]$IncludeDirectX,
    [switch]$IncludeDotNet,
    [switch]$Quiet,
    [string]$ProgressFile,
    [switch]$FromPayload,
    [string]$Only
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $root 'payload'
$logFile = Join-Path $root 'install-offline.log'

$script:okCount = 0
$script:failList = @()

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    if (-not $Quiet) { Write-Host $Message -ForegroundColor $Color }
    Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -Encoding UTF8
}

function Write-Step {
    param([string]$Line)
    if ($ProgressFile) {
        try { Add-Content -LiteralPath $ProgressFile -Value $Line -Encoding UTF8 } catch { }
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-InstallerStep {
    param([hashtable]$Step)

    $dir = Join-Path $payload $Step.Folder
    $exe = Get-ChildItem $dir -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Log ("  [MISS] {0} - installer not found in {1}" -f $Step.Name, $Step.Folder) 'Yellow'
        $script:failList += "$($Step.Name) (missing file)"
        return $false
    }

    Write-Log ("  [..] {0}  ({1})" -f $Step.Name, $exe.Name) 'Cyan'
    $p = Start-Process -FilePath $exe.FullName -ArgumentList $Step.Args -Wait -PassThru -NoNewWindow
    $code = $p.ExitCode
    # 0 = ok, 1638/1641/1645 = already installed / superseded, 3010 = ok but reboot needed
    if ($code -in 0, 1638, 1641, 1645, 3010) {
        if ($code -eq 3010) { Write-Log ("       ok (exit {0}, reboot pending)" -f $code) 'Green' }
        else { Write-Log '       ok' 'Green' }
        $script:okCount++
        return $true
    }

    Write-Log ("       FAILED (exit {0})" -f $code) 'Red'
    $script:failList += "$($Step.Name) (exit $code)"
    return $false
}

function Invoke-DirectXStep {
    $sfx = Join-Path $payload 'DirectX\directx_Jun2010_redist.exe'
    if (-not (Test-Path $sfx)) {
        Write-Log '       MISS: payload\DirectX\directx_Jun2010_redist.exe' 'Yellow'
        $script:failList += 'DirectX (missing file)'
        return $false
    }

    $tmp = Join-Path $env:TEMP ('dx_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Write-Log '  [..] extracting DirectX redist...' 'Cyan'
    Start-Process $sfx -ArgumentList "/Q /T:$tmp" -Wait -NoNewWindow | Out-Null

    $setup = Join-Path $tmp 'DXSETUP.exe'
    if (-not (Test-Path $setup)) {
        Write-Log '       FAILED: DXSETUP.exe not found after extract' 'Red'
        $script:failList += 'DirectX (extract failed)'
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }

    $p = Start-Process $setup -ArgumentList '/silent' -Wait -PassThru -NoNewWindow
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if ($p.ExitCode -eq 0) { Write-Log '       ok' 'Green'; $script:okCount++; return $true }

    Write-Log ("       FAILED (exit {0})" -f $p.ExitCode) 'Red'
    $script:failList += "DirectX (exit $($p.ExitCode))"
    return $false
}

# ---------------------------------------------------------------- component table
$core = @(
    @{ Name = 'VC++ 2005 x86'; Folder = 'Microsoft.VCRedist.2005.x86'; Args = @('/Q', '/C:"msiexec /i ""vcredist.msi"" /quiet /norestart"') },
    @{ Name = 'VC++ 2005 x64'; Folder = 'Microsoft.VCRedist.2005.x64'; Args = @('/Q', '/C:"msiexec /i ""vcredist.msi"" /quiet /norestart"') },
    @{ Name = 'VC++ 2008 x86'; Folder = 'Microsoft.VCRedist.2008.x86'; Args = @('/qn') },
    @{ Name = 'VC++ 2008 x64'; Folder = 'Microsoft.VCRedist.2008.x64'; Args = @('/qn') },
    @{ Name = 'VC++ 2010 x86'; Folder = 'Microsoft.VCRedist.2010.x86'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2010 x64'; Folder = 'Microsoft.VCRedist.2010.x64'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2012 x86'; Folder = 'Microsoft.VCRedist.2012.x86'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2012 x64'; Folder = 'Microsoft.VCRedist.2012.x64'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2013 x86'; Folder = 'Microsoft.VCRedist.2013.x86'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2013 x64'; Folder = 'Microsoft.VCRedist.2013.x64'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2015-2022 (v14) x86'; Folder = 'Microsoft.VCRedist.2015+.x86'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VC++ 2015-2022 (v14) x64'; Folder = 'Microsoft.VCRedist.2015+.x64'; Args = @('/quiet', '/norestart') },
    @{ Name = 'VSTO 4.0 Runtime'; Folder = 'Microsoft.VSTOR'; Args = @('/q', '/norestart') }
)
$coreLookup = @{}
foreach ($i in $core) { $coreLookup[$i.Folder] = $i }

$steps = @()

function Add-StepForFolder {
    param([string]$Folder)

    if ($Folder -eq 'dotnet') {
        $dnRoot = Join-Path $payload 'dotnet'
        if (-not (Test-Path $dnRoot)) { return }
        foreach ($dir in (Get-ChildItem $dnRoot -Directory | Sort-Object Name)) {
            $script:steps += @{ Kind = 'pkg'; Name = $dir.Name; Folder = "dotnet\$($dir.Name)"; Args = @('/install', '/quiet', '/norestart') }
        }
        return
    }

    if ($Folder -eq 'DirectX') {
        $script:steps += @{ Kind = 'directx'; Name = 'Legacy DirectX (June 2010)'; Folder = 'DirectX' }
        return
    }

    if ($coreLookup.ContainsKey($Folder)) {
        $i = $coreLookup[$Folder]
        $script:steps += @{ Kind = 'pkg'; Name = $i.Name; Folder = $i.Folder; Args = $i.Args }
    }
}

# ---------------------------------------------------------------- preflight
if (-not (Test-Admin)) {
    Write-Host 'ERROR: Administrator rights are required. Please run install-offline.cmd' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $payload)) {
    Write-Host "ERROR: payload folder not found: $payload" -ForegroundColor Red
    Write-Host 'Run build-bundle.ps1 once while online.' -ForegroundColor Yellow
    exit 1
}

"=== Offline runtimes install started $(Get-Date) ===" | Set-Content -LiteralPath $logFile -Encoding UTF8
if ($ProgressFile) { Remove-Item -LiteralPath $ProgressFile -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------- build step list
if ($Only) {
    foreach ($folder in ($Only -split ',' | Where-Object { $_.Trim() })) {
        Add-StepForFolder $folder.Trim()
    }
}
elseif ($FromPayload) {
    foreach ($i in $core) {
        if (Test-Path (Join-Path $payload $i.Folder)) { Add-StepForFolder $i.Folder }
    }
    Add-StepForFolder 'dotnet'
    if (Test-Path (Join-Path $payload 'DirectX\directx_Jun2010_redist.exe')) { Add-StepForFolder 'DirectX' }
}
else {
    foreach ($i in $core) { Add-StepForFolder $i.Folder }
    if ($IncludeDotNet) { Add-StepForFolder 'dotnet' }
    if ($IncludeDirectX) { Add-StepForFolder 'DirectX' }
}

if ($steps.Count -eq 0) {
    Write-Log 'Nothing selected - no component to install.' 'Yellow'
    Write-Step 'TOTAL|0'
    Write-Step 'FINISH|0'
    exit 0
}

# ---------------------------------------------------------------- run
Write-Log ("Installing {0} component(s)..." -f $steps.Count) 'White'
Write-Step ("TOTAL|{0}" -f $steps.Count)

foreach ($step in $steps) {
    Write-Step ("BEGIN|{0}" -f $step.Name)
    if ($step.Kind -eq 'directx') { $ok = Invoke-DirectXStep } else { $ok = Invoke-InstallerStep $step }
    Write-Step ("{0}|{1}" -f $(if ($ok) { 'DONE' } else { 'FAIL' }), $step.Name)
}

# ---------------------------------------------------------------- summary
$rebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

Write-Log ''
Write-Log ('===== Summary: {0} installed/touched, {1} failed =====' -f $script:okCount, $script:failList.Count) 'Yellow'
if ($script:failList.Count -gt 0) { foreach ($f in $script:failList) { Write-Log ("  FAILED: {0}" -f $f) 'Red' } }
if ($rebootPending) { Write-Log 'Reboot is recommended to finish installation.' 'Yellow' }
Write-Log ("Log: {0}" -f $logFile)

Write-Step ("FINISH|{0}" -f $script:failList.Count)

exit ([int]($script:failList.Count -gt 0))
