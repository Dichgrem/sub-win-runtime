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

function Get-IsccPortable {
    $tools = Join-Path $PSScriptRoot 'tools'
    New-Item -ItemType Directory -Force -Path $tools | Out-Null

    # innoextract (open-source Inno Setup unpacker)
    $innoEx = (Get-ChildItem $tools -Recurse -Filter innoextract.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
    if (-not $innoEx) {
        Write-Host 'fetching innoextract...' -ForegroundColor Cyan
        $rel = Invoke-RestMethod 'https://api.github.com/repos/dscharrer/innoextract/releases/latest' -Headers @{'User-Agent'='PowerShell'}
        $asset = $rel.assets | Where-Object { $_.name -match 'windows' } | Select-Object -First 1
        $zip = Join-Path $tools 'innoextract.zip'
        Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tools -Force
        $innoEx = (Get-ChildItem $tools -Recurse -Filter innoextract.exe | Select-Object -First 1).FullName
    }

    # Inno Setup installer via winget
    $dl = Join-Path $tools 'inno-dl'
    if (-not (Get-ChildItem $dl -Recurse -Filter *.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'fetching Inno Setup...' -ForegroundColor Cyan
        winget download --exact --id JRSoftware.InnoSetup --download-directory $dl `
            --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    }
    $setup = Get-ChildItem $dl -Recurse -Filter *.exe | Select-Object -First 1

    $out = Join-Path $tools 'inno'
    Write-Host 'extracting Inno Setup (portable)...' -ForegroundColor Cyan
    & $innoEx -e -d $out --no-warn $setup.FullName | Out-Null

    $iscc = (Get-ChildItem $out -Recurse -Filter ISCC.exe | Select-Object -First 1).FullName
    if (-not $iscc) { throw 'ISCC.exe not found after extraction' }
    return $iscc
}

$iscc = Find-Iscc
if (-not $iscc) { $iscc = Get-IsccPortable }
Write-Host "ISCC: $iscc" -ForegroundColor Green

# ---------- 3. compile ----------
$defs = @()
if ($IncludeDirectX) { $defs += '/DINCLUDE_DIRECTX' }
if ($IncludeDotNet)  { $defs += '/DINCLUDE_DOTNET' }

Write-Host 'compiling offline installer...' -ForegroundColor Yellow
& $iscc @defs (Join-Path $root 'installer.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

$outExe = Get-ChildItem (Join-Path $root 'dist') -Filter *.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host ("`nDONE -> {0} ({1:N1} MB)`n" -f $outExe.FullName, ($outExe.Length / 1MB)) -ForegroundColor Green
