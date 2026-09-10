# 指南

## 使用

### 离线 · 单文件（推荐）

构建机（联网）：

```powershell
.\build-bundle.ps1        # 下载官方安装器 → payload/
.\build-installer.ps1     # → dist\windows-runtimes-offline-setup.exe
```

目标机：拷贝 exe → 双击 → UAC → 静默安装 → 需要时重启。
日志：`%ProgramFiles%\WindowsRuntimesOffline\install.log`

### 离线 · 文件夹（独立脚本运行）

```powershell
.\build-bundle.ps1                     # 只需 payload/
# 拷到目标机后：
.\run-offline.cmd                  # 双击，自动提权
.\install-offline.ps1                  # 或管理员 PowerShell 直接运行
```

### 在线 · winget（独立脚本运行）

```powershell
.\install-online.ps1                        # 核心 13 项
.\install-online.ps1 -IncludeDirectX        # + legacy DirectX
.\install-online.ps1 -IncludeDotNetRuntimes # + .NET 6/8/10
.\install-online.ps1 -IncludeDotNet35       # + 启用 .NET Framework 3.5（DISM）
```

### 可选组件

| 参数                                        | 内容                                       | 增量    |
| ------------------------------------------- | ------------------------------------------ | ------- |
| `-IncludeDirectX`                           | legacy DirectX 9/10/11（June 2010 完整包） | ~+60 MB |
| `-IncludeDotNet` / `-IncludeDotNetRuntimes` | .NET 6/8/10 runtime/desktop                | ~+50 MB |

### 验证

```powershell
# 内层安装器签名（期望 13/13 Valid / CN=Microsoft Corporation）
Get-ChildItem payload -Recurse -Filter *.exe |
  Get-AuthenticodeSignature | Select Status, @{n='Signer';e={$_.SignerCertificate.Subject}}

winget list --source winget | Select-String 'VCRedist|VSTOR'
```

### FAQ

| 问题               | 说明                                                                                                        |
| ------------------ | ----------------------------------------------------------------------------------------------------------- |
| "未知发布者"提示   | 外层安装器无代码签名证书；内层 13 个均为微软签名。可配证书 + Inno `SignTool`                                |
| 为什么 117 MB      | 内层是 13 个微软安装器（本身已压缩），二次压缩收益有限                                                      |
| 重复运行           | 安全。MSI/Burn 自带版本检测，已装即秒退                                                                     |
| .NET Framework 3.5 | 需系统安装介质：`DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:X:\sources\sxs` |
| 卸载               | 控制面板卸载 "Windows Runtimes Offline"；已装运行库为独立组件，不会被移除                                   |
| 刷新版本           | `.\build-bundle.ps1 -Force` → `.\build-installer.ps1`                                                       |

---

## 构建

### 要求

| 项         | 要求                                                                         |
| ---------- | ---------------------------------------------------------------------------- |
| 构建机     | Windows 10/11 x64，PowerShell 5.1+，winget                                   |
| Inno Setup | `build-installer.ps1` 自动检测；缺失时 `winget install JRSoftware.InnoSetup` |
| 网络       | 仅构建时                                                                     |

### 命令

```powershell
.\build-bundle.ps1 [-Force] [-IncludeDirectX] [-IncludeDotNet]   # → payload/
.\build-installer.ps1 [-IncludeDirectX] [-IncludeDotNet]         # → dist/*.exe
```

### 打包参数（installer.iss）

| 项                 | 值                                                      |
| ------------------ | ------------------------------------------------------- |
| 压缩 / 权限 / 架构 | `lzma2/ultra64` solid / `admin` / `x64compatible`       |
| 排除 / 入口        | `*.yaml` / `[Run] powershell -File install-offline.ps1` |

### CI

`.github/workflows/build.yml` — 手动触发（勾选 DirectX / .NET / 发布 Release），或推送 `v*` tag 自动构建并附加到 Release。
二进制不入库，CI 每次从微软 CDN 重新获取。

### 仓库约定

- 不入库：`payload/`、`dist/`、`tools/`、`*.log`
- 行尾：`*.ps1|*.cmd|*.iss` = CRLF（batch 的 label/goto 依赖 CRLF），`*.yml|*.md` = LF

---

## 参考

### 包清单

| winget 包 ID                            | 组件                            | 类型      |
| --------------------------------------- | ------------------------------- | --------- |
| `Microsoft.VCRedist.2005.x86` / `.x64`  | VC++ 2005                       | SFX + MSI |
| `Microsoft.VCRedist.2008.x86` / `.x64`  | VC++ 2008                       | exe       |
| `Microsoft.VCRedist.2010.x86` / `.x64`  | VC++ 2010                       | exe       |
| `Microsoft.VCRedist.2012.x86` / `.x64`  | VC++ 2012                       | Burn      |
| `Microsoft.VCRedist.2013.x86` / `.x64`  | VC++ 2013                       | Burn      |
| `Microsoft.VCRedist.2015+.x86` / `.x64` | VC++ 2015-2022                  | Burn      |
| `Microsoft.VSTOR`                       | VS Tools for Office Runtime 4.0 | exe       |
| `Microsoft.DirectX`                     | legacy DirectX 9/10/11（可选）  | SFX       |
| `Microsoft.DotNet.*`                    | .NET 6/8/10（可选）             | exe       |

### 静默参数

取自各包官方 winget manifest 的 `InstallerSwitches.Silent`，原样使用。

| 组件                                | 参数                                                    |
| ----------------------------------- | ------------------------------------------------------- |
| VC++ 2005                           | `/Q /C:"msiexec /i ""vcredist.msi"" /quiet /norestart"` |
| VC++ 2008                           | `/qn`                                                   |
| VC++ 2010 / 2012 / 2013 / 2015-2022 | `/quiet /norestart`                                     |
| VSTO 4.0                            | `/q /norestart`                                         |
| DirectX                             | `/Q /T:<tmp>` → `DXSETUP.exe /silent`                   |
| .NET 6/8/10                         | `/install /quiet /norestart`                            |

### 退出码

| 码                 | 含义                  | 处理          |
| ------------------ | --------------------- | ------------- |
| 0                  | 成功                  | ✅            |
| 1638               | 已装更高版本          | ✅            |
| 1641 / 1645 / 3010 | 成功（3010 = 需重启） | ✅ + 重启提示 |
| 其他               | 失败                  | ❌ → `exit 1` |

### 路径

| 路径                                      | 说明                             |
| ----------------------------------------- | -------------------------------- |
| `payload/<PackageId>/`                    | 官方安装器 + manifest（`.yaml`） |
| `payload/dotnet/`、`payload/DirectX/`     | 可选载荷                         |
| `dist/windows-runtimes-offline-setup.exe` | 单文件安装器                     |
| `%ProgramFiles%\WindowsRuntimesOffline\`  | 目标机安装位置（含日志）         |

### 不覆盖

| 组件                       | 原因                                          |
| -------------------------- | --------------------------------------------- |
| .NET Framework 3.5         | 需系统安装介质（`DISM /Source:\sources\sxs`） |
| UCRT KB3118401 / KB2999226 | 仅 Win7/8 需要，Win10/11 已内置               |
| VB6 运行库 / MSXML         | 官方无 winget 包                              |

### 溯源

`winget download` 同时落盘 manifest（含 `InstallerUrl` / `InstallerSha256`），可据此校验载荷来源。
Inno Setup 为公开格式，可用 [innoextract](https://github.com/dscharrer/innoextract) 检视任意 Inno 安装包。

### 许可

脚本 [MIT](../LICENSE) © 2026 Dichgrem。微软安装器不在仓库内，构建时从官方渠道获取并校验 SHA-256，版权与许可归 Microsoft。
构建期临时获取的第三方工具（不分发）：[innoextract](https://github.com/dscharrer/innoextract)（zlib）、[Inno Setup 6](https://jrsoftware.org/isinfo.php)。
