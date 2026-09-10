#requires -Version 5.1
<#
.SYNOPSIS
    Build a single-file offline installer (dist\windows-runtimes-offline-setup.exe).

.DESCRIPTION
    1. Ensures payload/ exists (calls build-bundle.ps1 when missing)
    2. Locates ISCC.exe (Inno Setup compiler); if absent, fetches it portably
       (winget download + innoextract) into tools\ - no admin needed
    3. Compiles installer.iss

.EXAMPLE
    .\build-installer.ps1
    .\build-installer.ps1 -IncludeDirectX -IncludeDotNet
#>
[CmdletBinding()]
param(
    [switch]$IncludeDirectX,
    [switch]$IncludeDotNet
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# ---------- 1. payload ----------
$payload = Join-Path $root 'payload'
if (-not (Test-Path (Join-Path $payload 'Microsoft.VCRedist.2015+.x64'))) {
    Write-Host 'payload missing -> running build-bundle.ps1 (needs network)' -ForegroundColor Yellow
    & (Join-Path $root 'build-bundle.ps1') -IncludeDirectX:$IncludeDirectX -IncludeDotNet:$IncludeDotNet
}

# ---------- 2. ISCC ----------
function Find-Iscc {
    $cands = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path $PSScriptRoot 'tools\inno\ISCC.exe'),
        (Join-Path $PSScriptRoot 'tools\Inno Setup 6\ISCC.exe')
    )
    foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

function Install-Iscc {
    Write-Host 'Inno Setup not found -> installing via winget...' -ForegroundColor Cyan
    winget install --exact --id JRSoftware.InnoSetup `
        --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    $found = Find-Iscc
    if (-not $found) { throw 'Inno Setup installed, but ISCC.exe not found' }
    return $found
}

$iscc = Find-Iscc
if (-not $iscc) { $iscc = Install-Iscc }
Write-Host "ISCC: $iscc" -ForegroundColor Green

# ---------- 3. compile ----------
$defs = @()
# auto-detect optional payload so the component picker offers exactly what is bundled
$hasDotNet = (Test-Path (Join-Path $root 'payload\dotnet')) -and
(Get-ChildItem (Join-Path $root 'payload\dotnet') -Recurse -Filter *.exe -ErrorAction SilentlyContinue)
$hasDirectX = Test-Path (Join-Path $root 'payload\DirectX\directx_Jun2010_redist.exe')

if ($IncludeDirectX -or $hasDirectX) { $defs += '/DINCLUDE_DIRECTX' }
if ($IncludeDotNet -or $hasDotNet) { $defs += '/DINCLUDE_DOTNET' }

Write-Host 'compiling offline installer...' -ForegroundColor Yellow
& $iscc @defs (Join-Path $root 'installer.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

$outExe = Get-ChildItem (Join-Path $root 'dist') -Filter *.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host ("`nDONE -> {0} ({1:N1} MB)`n" -f $outExe.FullName, ($outExe.Length / 1MB)) -ForegroundColor Green
