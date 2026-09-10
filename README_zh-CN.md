# sub-win-runtime

微软常用运行库离线安装器，全部由官方 winget 源构建。

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20x64-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](README.md)

## 安装

```powershell
git clone https://github.com/Dichgrem/sub-win-runtime.git
cd sub-win-runtime
.\build-bundle.ps1        # 下载官方安装器 → payload/（约 124 MB，需联网）
.\build-installer.ps1     # → dist\windows-runtimes-offline-setup.exe（约 117 MB）
```

把 exe 拷到任意 Windows 10/11 x64 机器双击即可，**无需联网**。
两个脚本后加 `-IncludeDirectX` / `-IncludeDotNet` 可附带 legacy DirectX 与 .NET 6/8/10。

目标机有网时可直接用 winget：`.\install-online.ps1`

## 工作原理

```
winget manifest（URL + SHA-256 + 静默参数）
  └─ build-bundle.ps1       → payload/            微软签名安装器
     └─ build-installer.ps1 → 单文件 exe          Inno Setup + LZMA2
        └─ 双击             → UAC → install-offline.ps1 → MSI/Burn 静默安装
```

## 覆盖范围

| 组件 | winget 包 ID |
|---|---|
| VC++ 2005 / 2008 / 2010 / 2012 / 2013 / 2015-2022（x86 + x64）| `Microsoft.VCRedist.*` |
| Visual Studio Tools for Office Runtime 4.0 | `Microsoft.VSTOR` |
| legacy DirectX 9/10/11（可选）| `Microsoft.DirectX` |
| .NET 6 / 8 / 10（可选）| `Microsoft.DotNet.*` |

## 文档

[指南](docs/guide.md) —— 使用、构建、参考

## 许可

MIT。微软安装器由构建时从官方渠道获取，本仓库不分发这些二进制。
