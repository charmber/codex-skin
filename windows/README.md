# Codex Dream Skin for Windows

适用于 Microsoft Store 官方 Codex Desktop 的非官方主题工作室。通过 `127.0.0.1` 回环 CDP 应用主题，不修改 `WindowsApps`、`app.asar` 或官方签名。

## 安装

1. 从 [GitHub Releases](https://github.com/charmber/codex-skin/releases) 下载 `Codex-Dream-Skin-Windows-*-x64.exe`。
2. 安装版可选择安装目录并创建桌面/开始菜单快捷方式；便携版文件名包含 `portable`，可直接运行。
3. 首次打开后进入主题工作室，托盘区会同时出现 Codex Dream Skin 图标。
4. 点击“保存并应用”或托盘菜单“应用皮肤”。如果 Codex 已经运行但没有 CDP，应用会先询问是否重启。

当前 EXE 未购买 Windows 代码签名证书，SmartScreen 可能显示“未知发布者”。请只从本仓库 Release 下载，并用同一 Release 中的 `SHA256SUMS-Windows.txt` 核对文件。

## 功能

- 托盘控制：应用、暂停、恢复官方外观、主题商店、开机启动、日志和背景目录
- 主题工作室：背景预览、布局、配色、10 项颜色、文案、对话头像、阅读区效果和经典蓝组件
- 热切换：布局、配色、背景和历史主题；CDP 已运行时无需重启 Codex
- 主题包：导入/导出与 macOS 通用的 `.cds-theme.zip`
- 更新适配：每次启动动态发现当前 `OpenAI.Codex` Store 包

主题与状态保存在：

```text
%LOCALAPPDATA%\CodexDreamSkinStudio
├── theme\       当前主题
├── themes\      历史与导入主题
├── images\      背景库
├── logs\        注入日志
└── state.json   本机 CDP / watcher 状态
```

卸载应用默认保留主题库。需要清理时，请先从托盘选择“完全恢复官方外观”，退出应用后再删除上述用户目录。

## 安全边界

- CDP 只绑定 `127.0.0.1`；主题启用期间不要运行来源不明的本机程序
- Codex 未以 CDP 启动时会明确询问是否重启，不会静默结束应用
- 不写入 `WindowsApps`，不修改 `app.asar`、签名、账户、API Key、Base URL 或模型配置
- 主题 ZIP 不允许 JS、CSS、PowerShell、Shell、可执行文件、路径穿越或符号链接
- 主题商店只在点击后打开，不自动上传主题或账户数据；站点当前为 HTTP，请勿提交敏感信息

## 从源码构建

需要 Node.js 24：

```powershell
cd windows\app
npm ci
npm test
npm run build
```

产物位于 `windows\release\`：安装版 EXE、便携版 EXE 和构建元数据。公开版本由 [Windows Release workflow](../.github/workflows/windows-release.yml) 在 `v*` 标签推送时自动构建并上传。

`windows/scripts/*.ps1` 继续作为旧版单主题兼容入口；新安装推荐使用 EXE。
