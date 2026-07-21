# Codex Dream Skin 1.11.3

## Windows

- 修复设置提问/回答头像后保存并应用时，聊天页可能提示 `Renderer evaluation failed: SyntaxError` 的问题
- 保存成功但即时应用失败时，现在会保留主题并显示准确的应用错误，不再误报为保存失败
- 提供安装版与便携版 x64 EXE，以及 `SHA256SUMS-Windows.txt`

## macOS

- 同步修复未来舞台布局的首页建议区选择器，避免部分 DOM 状态下热应用失败

## 安全边界

- Windows 与 macOS 都只通过 `127.0.0.1` 回环 CDP 注入
- 不修改官方应用、`app.asar`、代码签名、账户或 API 配置
- Windows 主题包只允许声明式 JSON、图片和说明/许可文件，不执行包内代码

Windows EXE 当前未签名，SmartScreen 可能显示“未知发布者”。请只从本仓库 Release 下载并核对 SHA-256。
