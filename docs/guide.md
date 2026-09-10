# 指南

## 使用

### 离线 · 单文件（推荐）

构建机（联网）：

```powershell
.\build-bundle.ps1        # 下载官方安装器 → payload/（核心约 124 MB）
.\build-installer.ps1     # → dist\windows-runtimes-<日期>.exe
```

目标机：拷贝 exe → 双击 → UAC → **选择组件** → **安装进度页** → 完成（必要时重启）

| 项       | 说明                                                |
| -------- | --------------------------------------------------- |
| 产物大小 | 核心约 126 MB；若打包了 .NET/DirectX 约 444 MB      |
| 安装日志 | `%ProgramFiles%\WindowsRuntimesOffline\install.log` |
| 安装位置 | `%ProgramFiles%\WindowsRuntimesOffline\`            |

**组件选择页**（只有打包进 exe 的组件才会出现选项）

| 选项              | 内容                                                                              | 默认    |
| ----------------- | --------------------------------------------------------------------------------- | ------- |
| Visual C++ 运行库 | VC++ 2005 / 2008 / 2010 / 2012 / 2013 / 2015-2022（各含 x86 + x64，可逐版本勾选） | ✅ 勾选 |
| VSTO 4.0          | Visual Studio Tools for Office Runtime                                            | ✅ 勾选 |
| .NET 运行时       | .NET 6 / 8 / 10 runtime + desktop（需 payload 含 `dotnet/`）                      | 需打包  |
| legacy DirectX    | DirectX 9/10/11（June 2010 完整包，需 payload 含 `DirectX/`）                     | 需打包  |

- 安装类型：**完整安装** / **推荐安装（VC++ + VSTO）** / **自定义安装**
- **未勾选的组件不会被解包，也不会安装**；每次安装前会自动清空上次残留的 payload
- 安装阶段有**真实进度条**（按组件推进）+ 两行实时文字（`正在安装：<组件>` / `已完成 n / N`），过程中的 PowerShell 窗口是隐藏的

### 离线 · 文件夹（独立脚本运行）

```powershell
.\build-bundle.ps1                     # 只需 payload/
# 拷到目标机后：
.\run-offline.cmd                      # 双击（自动提权 → 调引擎）
.\install-offline.ps1                  # 或管理员 PowerShell 直接运行
```

### 在线 · winget（独立脚本运行）

```powershell
.\install-online.ps1                        # 核心 13 项
.\install-online.ps1 -IncludeDirectX        # + legacy DirectX
.\install-online.ps1 -IncludeDotNetRuntimes # + .NET 6/8/10
.\install-online.ps1 -IncludeDotNet35       # + 启用 .NET Framework 3.5（DISM）
```

### 脚本一览

| 文件                  | 角色                                                                |
| --------------------- | ------------------------------------------------------------------- |
| `install-offline.ps1` | **离线安装引擎**：逐组件静默安装、写进度文件、判定退出码、写日志    |
| `run-offline.cmd`     | **文件夹模式双击入口**：检测提权 → `runas` 重拉自己 → 调引擎        |
| `install-online.ps1`  | **在线模式**：直接用 winget 安装（无需 payload）                    |
| `build-bundle.ps1`    | 构建侧：下载官方安装器到 `payload/`（构建前自动刷新 winget 源索引） |
| `build-installer.ps1` | 构建侧：编译 `installer.iss` → `dist\windows-runtimes-<日期>.exe`   |
| `installer.iss`       | Inno 工程：组件选择页、进度页、图标、卸载项                         |

### 可选组件（打包时决定）

| 参数              | 内容                                                                           | payload 增量 | 产物增量  |
| ----------------- | ------------------------------------------------------------------------------ | ------------ | --------- |
| `-IncludeDirectX` | legacy DirectX 9/10/11（June 2010 完整包）                                     | +95.6 MB     | ≈ +96 MB  |
| `-IncludeDotNet`  | .NET 6/8/10（Runtime 6/8、DesktopRuntime 6/8/10、AspNetCore 8，共 6 个安装器） | +232.1 MB    | ≈ +232 MB |

> 不打包对应载荷，组件选择页里就不会出现该选项。`build-installer.ps1` 会自动探测 `payload/` 内容，无需重复传参。

### 验证

```powershell
# 内层安装器签名（核心 13 项；勾选可选组件后共 20 项，期望全部 Valid / CN=Microsoft Corporation）
Get-ChildItem payload -Recurse -Filter *.exe |
  Get-AuthenticodeSignature | Select Status, @{n='Signer';e={$_.SignerCertificate.Subject}}

# 已装组件
winget list --source winget | Select-String 'VCRedist|VSTOR'

# 本次安装结果（Summary 行）
Get-Content 'C:\Program Files\WindowsRuntimesOffline\install.log' -Tail 10
```

### FAQ

| 问题                        | 说明                                                                                                                                            |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| "未知发布者"提示            | 外层安装器无代码签名证书；内层安装器（核心 13 项 / 含可选共 20 项）均为微软签名。可配证书 + Inno `SignTool` 消除                                |
| 产物是 126 MB 还是 444 MB？ | 取决于打包内容：核心（VC++ + VSTO）≈ 126 MB；含 .NET（232 MB）+ DirectX（96 MB）≈ 444 MB                                                        |
| 重复运行                    | 安全。MSI/Burn 自带版本检测，已装即秒退                                                                                                         |
| .NET Framework 3.5          | 安装器暂不集成；需 Windows 安装介质或 Windows 更新：`DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:X:\sources\sxs` |
| 卸载                        | 控制面板卸载 "Windows Runtimes Offline"；已安装的运行库是独立组件，不会被移除                                                                   |
| 刷新到最新版                | `.\build-bundle.ps1 -Force` → `.\build-installer.ps1`                                                                                           |

---

## 构建

### 要求

| 项         | 要求                                                                                 |
| ---------- | ------------------------------------------------------------------------------------ |
| 构建机     | Windows 10/11 x64，PowerShell 5.1+，winget                                           |
| Inno Setup | `build-installer.ps1` 自动检测；缺失时自动 `winget install JRSoftware.InnoSetup`     |
| 网络       | 仅构建时；每次构建会先执行 `winget source update` 刷新源索引，确保取到最新已发布版本 |

### 命令

```powershell
.\build-bundle.ps1 [-Force] [-IncludeDirectX] [-IncludeDotNet]   # → payload/
.\build-installer.ps1                                            # → dist\windows-runtimes-<日期>.exe
```

### 打包参数（installer.iss）

| 项          | 值                                                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| 压缩 | `lzma2/ultra64` + solid |
| 权限 / 架构 | `admin` / `x64compatible`                                                                                                |
| 排除        | `*.yaml`                                                                                                                 |
| 安装入口    | `[Code]` 中隐藏调用 `install-offline.ps1 -Quiet -Only <选中组件> -ProgressFile <temp>`，进度页的进度条与文字由该文件驱动 |
| 图标        | `assets/app.ico`（9 尺寸：16/20/24/32/40/48/64/128/256），同时用于 setup.exe、向导窗口与控制面板条目                     |
| 版本 / 命名 | `AppVersion` 与产物名均取构建日期：`windows-runtimes-<YYYY-MM-DD>.exe`                                                   |

### CI

`.github/workflows/build.yml`

- **仅手动触发**（Actions → build-and-release → Run workflow），无输入项
- 默认全量：`build-bundle.ps1 -IncludeDirectX -IncludeDotNet` → `build-installer.ps1`
- 构建成功后**自动发布 Release**：
  - tag 与标题：`v<日期>`（如 `v2026-09-10`）
  - 附件：`windows-runtimes-<日期>.exe` + `windows-runtimes-<日期>.exe.sha256`
  - 正文由 GitHub 自动生成（What's Changed / Full Changelog）
  - 同一天重复运行会更新同一个 Release 并覆盖附件
- 二进制不入库，每次从微软官方渠道重新获取

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
| `Microsoft.DotNet.*`                    | .NET 6/8/10（可选，6 个安装器） | exe       |

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

| 路径                                     | 说明                               |
| ---------------------------------------- | ---------------------------------- |
| `payload/<PackageId>/`                   | 官方安装器 + manifest（`.yaml`）   |
| `payload/dotnet/`、`payload/DirectX/`    | 可选载荷                           |
| `dist/windows-runtimes-<日期>.exe`       | 单文件安装器                       |
| `assets/app.ico`                         | 图标（构建时嵌入 exe）             |
| `%ProgramFiles%\WindowsRuntimesOffline\` | 目标机安装位置（含 `install.log`） |

### 溯源

`winget download` 同时落盘 manifest（含 `InstallerUrl` / `InstallerSha256`），可据此校验载荷来源。
Inno Setup 为公开格式，可用 [innoextract](https://github.com/dscharrer/innoextract) 检视任意 Inno 安装包。

### 许可

脚本 [MIT](../LICENSE) © 2026 Dichgrem。微软安装器不在仓库内，构建时从官方渠道获取并校验 SHA-256，版权与许可归 Microsoft。
构建期临时获取的第三方工具（不分发）：[innoextract](https://github.com/dscharrer/innoextract)（zlib）、[Inno Setup 6](https://jrsoftware.org/isinfo.php)。
