# sub-win-runtime

Offline installer for the common Microsoft runtimes, built from official winget sources.

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20x64-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[中文](README_zh-CN.md)

## Install

```powershell
git clone https://github.com/Dichgrem/sub-win-runtime.git
cd sub-win-runtime
.\build-bundle.ps1        # fetch official installers → payload/ (~124 MB, network needed)
.\build-installer.ps1     # → dist\windows-runtimes-offline-setup.exe (~117 MB)
```

Copy the exe to any Windows 10/11 x64 machine and double-click — no network required.
Append `-IncludeDirectX` / `-IncludeDotNet` to both scripts for legacy DirectX and .NET 6/8/10.

Already online? Use winget directly: `.\install-online.ps1`

## How It Works

```
winget manifest (URL + SHA-256 + silent switches)
  └─ build-bundle.ps1       → payload/            Microsoft-signed installers
     └─ build-installer.ps1 → single exe          Inno Setup + LZMA2
        └─ double-click     → UAC → install-offline.ps1 → MSI/Burn silent install
```

## Coverage

| Component | winget ID |
|---|---|
| VC++ 2005 / 2008 / 2010 / 2012 / 2013 / 2015-2022 (x86 + x64) | `Microsoft.VCRedist.*` |
| Visual Studio Tools for Office Runtime 4.0 | `Microsoft.VSTOR` |
| Legacy DirectX 9/10/11 *(optional)* | `Microsoft.DirectX` |
| .NET 6 / 8 / 10 *(optional)* | `Microsoft.DotNet.*` |

## Docs

[Guide](docs/guide.md) — usage, build, package reference

## License

MIT. Microsoft installers are fetched from official channels at build time and are not distributed by this repository.
