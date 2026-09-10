#requires -Version 5.1
<#
.SYNOPSIS
    Open-source replacement for "Microsoft Common Runtimes Collection" (微软常用运行库合集).
    Installs every component the bundle contains, but via winget (official Microsoft packages)
    instead of a third-party repack.

.DESCRIPTION
    Bundle components covered:
      VC++ 2005 / 2008 / 2010 / 2012 / 2013 / 2015-2022 (x86 + x64)  -> Microsoft.VCRedist.*
      Visual Studio Tools for Office Runtime 4.0                     -> Microsoft.VSTOR
    Optional (not in the bundle, separate flags):
      Legacy DirectX 9/10/11 (d3dx9_43.dll ...)                      -> Microsoft.DirectX
      .NET Framework 3.5 (DISM)                                      -> -IncludeDotNet35
      .NET modern runtimes 6/8/10                                    -> -IncludeDotNetRuntimes
    Not needed on Windows 10/11 (bundle carries them only for Win7/8):
      UCRT updates KB3118401 / KB2999226                             -> inbox on Win10+

.PARAMETER IncludeDirectX
    Also install the legacy DirectX End-User Runtime (for games using D3DX9/XAudio2.7/XInput1.3).

.PARAMETER IncludeDotNet35
    Enable .NET Framework 3.5 via DISM (requires admin; needs source media or Windows Update).

.PARAMETER IncludeDotNetRuntimes
    Also install .NET 6 / 8 / 10 runtimes + desktop runtimes.

.EXAMPLE
    .\install-online.ps1
    .\install-online.ps1 -IncludeDirectX -IncludeDotNetRuntimes
#>
[CmdletBinding()]
param(
    [switch]$IncludeDirectX,
    [switch]$IncludeDotNet35,
    [switch]$IncludeDotNetRuntimes
)

$ErrorActionPreference = 'Continue'

function Test-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error 'winget not found. Install "App Installer" from Microsoft Store first.'
        exit 1
    }
}

function Install-Package {
    param([string]$Id)
    Write-Host "==> $Id" -ForegroundColor Cyan
    winget install --exact --id $Id --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    (exit $LASTEXITCODE - already installed / no applicable upgrade is normal)" -ForegroundColor DarkGray
    }
}

Test-Winget

$core = @(
    'Microsoft.VCRedist.2005.x86', 'Microsoft.VCRedist.2005.x64',
    'Microsoft.VCRedist.2008.x86', 'Microsoft.VCRedist.2008.x64',
    'Microsoft.VCRedist.2010.x86', 'Microsoft.VCRedist.2010.x64',
    'Microsoft.VCRedist.2012.x86', 'Microsoft.VCRedist.2012.x64',
    'Microsoft.VCRedist.2013.x86', 'Microsoft.VCRedist.2013.x64',
    'Microsoft.VCRedist.2015+.x86', 'Microsoft.VCRedist.2015+.x64',
    'Microsoft.VSTOR'
)

if ($IncludeDirectX) { $core += 'Microsoft.DirectX' }
if ($IncludeDotNetRuntimes) {
    $core += @(
        'Microsoft.DotNet.Runtime.6', 'Microsoft.DotNet.Runtime.8',
        'Microsoft.DotNet.DesktopRuntime.6', 'Microsoft.DotNet.DesktopRuntime.8',
        'Microsoft.DotNet.DesktopRuntime.10', 'Microsoft.DotNet.AspNetCore.8'
    )
}

Write-Host "`nInstalling $($core.Count) packages via winget (idempotent)...`n" -ForegroundColor Yellow
foreach ($id in $core) { Install-Package $id }

if ($IncludeDotNet35) {
    Write-Host "`n==> Enabling .NET Framework 3.5 (DISM, requires admin)" -ForegroundColor Cyan
    dism /online /enable-feature /featurename:NetFx3 /all
}

Write-Host "`nDone. Verify with:  winget list --source winget`n" -ForegroundColor Green
