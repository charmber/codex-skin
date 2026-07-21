# Codex Dream Skin 1.11.2

## Windows

- 首个功能对齐 macOS 1.11 系列的 Windows 托盘 EXE：应用/暂停/恢复、开机启动、主题商店和运行状态集中管理
- 完整主题工作室：未来舞台与经典蓝 QQ 工作台、配色、背景、文案、双头像、阅读区效果和布局组件
- 支持热切换、历史主题以及跨平台 `.cds-theme.zip` 导入导出
- 提供安装版与便携版 EXE，以及 `SHA256SUMS-Windows.txt`

## macOS

- 修复原生菜单栏在图形环境未提供 `NODE` 变量时，“应用皮肤”可能立即报退出码 1 的问题

## 安全边界

- Windows 与 macOS 都只通过 `127.0.0.1` 回环 CDP 注入
- 不修改官方应用、`app.asar`、代码签名、账户或 API 配置
- Windows 主题包只允许声明式 JSON、图片和说明/许可文件，不执行包内代码

Windows EXE 当前未签名，SmartScreen 可能显示“未知发布者”。请只从本仓库 Release 下载并核对 SHA-256。
