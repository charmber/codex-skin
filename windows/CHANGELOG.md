# Windows Changelog

## 1.11.3 — 2026-07-21

### 修复

- 修复设置提问/回答头像后保存并应用主题时，聊天页可能因首页建议区选择器转义错误而提示 `Renderer evaluation failed: SyntaxError` 的问题
- 保存并应用现在会区分“主题保存失败”和“主题已保存但应用失败”，后者保留已保存主题并显示准确原因

### 说明

- 修复仍只通过 `127.0.0.1` 回环 CDP 应用主题，不修改 `WindowsApps`、`app.asar`、官方签名、账户或 API 配置

---

## 1.11.2 — 2026-07-21

### 新增

- 新增 Windows 原生托盘应用与 EXE 安装包，把应用皮肤、暂停、恢复、主题商店、开机启动、日志和背景目录集中到一个入口
- Windows 主题工作室补齐 macOS 当前能力：背景预览、两种布局、三套舞台配色、10 项颜色、首页/顶部文案、双头像、阅读区透明度与磨砂，以及经典蓝组件设置
- 支持布局、配色、背景和历史组合热切换；已存在回环 CDP 会话时不再强制完整重启
- 支持安全导入和导出 `.cds-theme.zip`，与 macOS 共用主题格式、渲染 API、布局和配色资源
- 新增标签触发的 GitHub Actions Windows 构建，发布安装版和便携版 EXE，并附 SHA-256 校验文件

### 改进

- EXE 自带可信 Node/Electron 运行时，不再要求用户全局安装 Node.js
- 动态发现当前 Microsoft Store `OpenAI.Codex` 包，升级 Codex 后无需维护版本化 `WindowsApps` 路径
- 旧版 PowerShell 兼容安装器不再强制 `appearanceTheme=light` 或改写浅色 Chrome 配置
- 主题状态、用户主题库、背景与日志统一保存到 `%LOCALAPPDATA%\CodexDreamSkinStudio`

### 安全

- CDP 显式绑定 `127.0.0.1`；仅在 Codex 未启用 CDP 时询问用户是否重启，不静默结束正在运行的 Codex
- 主题 ZIP 限制路径、符号链接、文件数量、解压体积、素材大小和未引用文件，并拒绝 JS、CSS、Shell 等可执行内容
- 不修改 `WindowsApps`、`app.asar`、官方签名、账户、API Key、Base URL 或模型配置
- 主题商店仅在用户点击后由默认浏览器打开；当前站点使用 HTTP，请勿提交密码、令牌或其他敏感信息

### 说明

- GitHub Release 的 Windows EXE 当前未购买代码签名证书；SmartScreen 可能显示“未知发布者”，请只从本仓库 Release 下载并核对 SHA-256

---
