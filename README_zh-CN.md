# sub-win-runtime <a href="README_zh-CN.md"><img align="right" alt="简体中文" src="https://img.shields.io/badge/%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue"></a><a href="README.md"><img align="right" alt="English" src="https://img.shields.io/badge/English-gray"></a>

微软常用运行库离线安装器，全部由官方 winget 源构建。

![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20x64-blue)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 安装

```powershell
git clone https://github.com/Dichgrem/sub-win-runtime.git
cd sub-win-runtime
.\build-bundle.ps1        # 下载官方安装器 → payload/（核心约 124 MB，需联网）
.\build-installer.ps1     # → dist\windows-runtimes-<日期>.exe（核心 126 MB / 含可选 444 MB）
```

把 exe 拷到任意 Windows 10/11 x64 机器双击即可，**无需联网**；安装时可在组件页勾选需要的组件。
两个脚本后加 `-IncludeDirectX` / `-IncludeDotNet` 可附带 legacy DirectX 与 .NET 6/8/10（打包后组件页才会出现对应选项）。

目标机有网时可直接用 winget：`.\install-online.ps1`
CI：手动触发 → 全量构建 → 自动发 Release `v<日期>`（附件 `windows-runtimes-<日期>.exe` + `.sha256`）。

## 工作原理

```
winget manifest（URL + SHA-256 + 静默参数）
  └─ build-bundle.ps1       → payload/            微软签名安装器
     └─ build-installer.ps1 → windows-runtimes-<日期>.exe   Inno Setup + 组件选择页
        └─ 双击             → UAC → 勾选组件 → install-offline.ps1 → MSI/Burn 静默安装
```

## 覆盖范围

| 组件                                                           | winget 包 ID           |
| -------------------------------------------------------------- | ---------------------- |
| VC++ 2005 / 2008 / 2010 / 2012 / 2013 / 2015-2022（x86 + x64） | `Microsoft.VCRedist.*` |
| Visual Studio Tools for Office Runtime 4.0                     | `Microsoft.VSTOR`      |
| legacy DirectX 9/10/11（可选）                                 | `Microsoft.DirectX`    |
| .NET 6 / 8 / 10（可选）                                        | `Microsoft.DotNet.*`   |
