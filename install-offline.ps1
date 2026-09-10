#requires -Version 5.1
<#
.SYNOPSIS
    Offline runtime installer - installs everything from .\payload, no network needed.
    Silent switches are taken verbatim from the official winget manifests.

.PARAMETER IncludeDirectX
    Install legacy DirectX (requires payload\DirectX\directx_Jun2010_redist.exe).

.PARAMETER IncludeDotNet
    Install .NET modern runtimes (requires payload\dotnet\*).

.PARAMETER Quiet
    No console progress (log file only).

.EXAMPLE
    .\install-offline.ps1
    .\install-offline.ps1 -IncludeDirectX -IncludeDotNet
#>
[CmdletBinding()]
param(
    [switch]$IncludeDirectX,
    [switch]$IncludeDotNet,
    [switch]$Quiet
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $root 'payload'
$logFile = Join-Path $root 'install-offline.log'

$script:okCount = 0
$script:skipCount = 0
$script:failList = @()

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    if (-not $Quiet) { Write-Host $Message -ForegroundColor $Color }
    Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -Encoding UTF8
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
Write-Log "Payload: $payload"
Write-Log ''

function Invoke-Installer {
    param([string]$Name, [string]$Folder, [string[]]$Arguments)

    $dir = Join-Path $payload $Folder
    $exe = Get-ChildItem $dir -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Log ("  [MISS] {0} - installer not found in {1}" -f $Name, $Folder) 'Yellow'
        $script:failList += "$Name (missing file)"
        return
    }

    Write-Log ("  [..] {0}  ({1})" -f $Name, $exe.Name) 'Cyan'
    $p = Start-Process -FilePath $exe.FullName -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    $code = $p.ExitCode
    # 0 = ok, 1638/1641/1645 = already installed / superseded, 3010 = ok but reboot needed
    if ($code -in 0, 1638, 1641, 1645, 3010) {
        if ($code -eq 3010) { Write-Log ("       ok (exit {0}, reboot pending)" -f $code) 'Green' }
        else { Write-Log '       ok' 'Green' }
        $script:okCount++
    }
    else {
        Write-Log ("       FAILED (exit {0})" -f $code) 'Red'
        $script:failList += "$Name (exit $code)"
    }
}

# ---------------------------------------------------------------- core (same as the classic bundle)
$items = @(
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

Write-Log ("Installing {0} core packages..." -f $items.Count) 'White'
foreach ($i in $items) { Invoke-Installer -Name $i.Name -Folder $i.Folder -Arguments $i.Args }

# ---------------------------------------------------------------- optional: legacy DirectX
if ($IncludeDirectX) {
    Write-Log ''
    Write-Log 'Installing legacy DirectX (June 2010)...' 'White'
    $sfx = Join-Path $payload 'DirectX\directx_Jun2010_redist.exe'
    if (Test-Path $sfx) {
        $tmp = Join-Path $env:TEMP ('dx_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        Write-Log '  [..] extracting redist...' 'Cyan'
        Start-Process $sfx -ArgumentList "/Q /T:$tmp" -Wait -NoNewWindow | Out-Null
        $setup = Join-Path $tmp 'DXSETUP.exe'
        if (Test-Path $setup) {
            $p = Start-Process $setup -ArgumentList '/silent' -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) { Write-Log '       ok' 'Green'; $script:okCount++ }
            else { Write-Log ("       FAILED (exit {0})" -f $p.ExitCode) 'Red'; $script:failList += "DirectX (exit $($p.ExitCode))" }
        }
        else { Write-Log '       FAILED: DXSETUP.exe not found after extract' 'Red'; $script:failList += 'DirectX (extract failed)' }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    else { Write-Log '       MISS: payload\DirectX\directx_Jun2010_redist.exe' 'Yellow'; $script:failList += 'DirectX (missing file)' }
}

# ---------------------------------------------------------------- optional: .NET modern runtimes
if ($IncludeDotNet) {
    Write-Log ''
    Write-Log 'Installing .NET modern runtimes...' 'White'
    $dnRoot = Join-Path $payload 'dotnet'
    if (Test-Path $dnRoot) {
        foreach ($dir in Get-ChildItem $dnRoot -Directory) {
            Invoke-Installer -Name $dir.Name -Folder "dotnet\$($dir.Name)" -Arguments @('/install', '/quiet', '/norestart')
        }
    }
    else { Write-Log '       MISS: payload\dotnet (run build-bundle.ps1 -IncludeDotNet)' 'Yellow' }
}

# ---------------------------------------------------------------- summary
$rebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

Write-Log ''
Write-Log ('===== Summary: {0} installed/touched, {1} failed =====' -f $script:okCount, $script:failList.Count) 'Yellow'
if ($script:failList.Count -gt 0) { foreach ($f in $script:failList) { Write-Log ("  FAILED: {0}" -f $f) 'Red' } }
if ($rebootPending) { Write-Log 'Reboot is recommended to finish installation.' 'Yellow' }
Write-Log ("Log: {0}" -f $logFile)

if (-not $Quiet) { Write-Host '' }
exit ([int]($script:failList.Count -gt 0))
