#requires -Version 5.1
<#
.SYNOPSIS
    Build the offline payload (downloads official Microsoft installers).
    Run this ONCE while online; the resulting payload/ works without network.

.EXAMPLE
    .\build-bundle.ps1                              # core only (VC++ 2005-2022 + VSTOR)
    .\build-bundle.ps1 -IncludeDotNet               # + .NET 6/8/10 runtimes
    .\build-bundle.ps1 -IncludeDirectX              # + legacy DirectX (June 2010, 95 MB)
    .\build-bundle.ps1 -IncludeDirectX -IncludeDotNet -Force
#>
[CmdletBinding()]
param(
    [switch]$IncludeDirectX,
    [switch]$IncludeDotNet,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $root 'payload'
New-Item -ItemType Directory -Force -Path $payload | Out-Null

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error 'winget is required to fetch official installers.'
    exit 1
}

$core = @(
    'Microsoft.VCRedist.2005.x86', 'Microsoft.VCRedist.2005.x64',
    'Microsoft.VCRedist.2008.x86', 'Microsoft.VCRedist.2008.x64',
    'Microsoft.VCRedist.2010.x86', 'Microsoft.VCRedist.2010.x64',
    'Microsoft.VCRedist.2012.x86', 'Microsoft.VCRedist.2012.x64',
    'Microsoft.VCRedist.2013.x86', 'Microsoft.VCRedist.2013.x64',
    'Microsoft.VCRedist.2015+.x86', 'Microsoft.VCRedist.2015+.x64',
    'Microsoft.VSTOR'
)
$dotnet = @(
    'Microsoft.DotNet.Runtime.6', 'Microsoft.DotNet.Runtime.8',
    'Microsoft.DotNet.DesktopRuntime.6', 'Microsoft.DotNet.DesktopRuntime.8',
    'Microsoft.DotNet.DesktopRuntime.10', 'Microsoft.DotNet.AspNetCore.8'
)

function Get-WingetPackage([string]$Id, [string]$TargetDir) {
    if ((Test-Path $TargetDir) -and -not $Force) {
        $existing = Get-ChildItem $TargetDir -Filter *.exe -ErrorAction SilentlyContinue
        if ($existing) { Write-Host "  skip (exists): $Id" -ForegroundColor DarkGray; return }
    }
    Write-Host "  downloading: $Id" -ForegroundColor Cyan
    winget download --exact --id $Id --download-directory $TargetDir `
        --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
}

Write-Host "`n=== Fetching official installers ===`n" -ForegroundColor Yellow
foreach ($id in $core) { Get-WinGetPackage $id (Join-Path $payload $id) }

if ($IncludeDotNet) {
    Write-Host "`n--- extra: .NET modern runtimes ---" -ForegroundColor Yellow
    foreach ($id in $dotnet) { Get-WinGetPackage $id (Join-Path $payload "dotnet\$id") }
}

if ($IncludeDirectX) {
    $dxDir = Join-Path $payload 'DirectX'
    New-Item -ItemType Directory -Force -Path $dxDir | Out-Null
    $dxFile = Join-Path $dxDir 'directx_Jun2010_redist.exe'
    if (-not (Test-Path $dxFile) -or $Force) {
        Write-Host "`n--- extra: legacy DirectX (June 2010, ~96 MB) ---" -ForegroundColor Yellow
        $url = 'https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe'
        Invoke-WebRequest -Uri $url -OutFile $dxFile -UseBasicParsing
    }
}

$total = (Get-ChildItem $payload -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Write-Host ("`n=== Payload ready: {0} files, {1:N1} MB ===`n" -f `
    (Get-ChildItem $payload -Recurse -File).Count, ($total / 1MB)) -ForegroundColor Green
