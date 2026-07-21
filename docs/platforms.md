# 平台对照

## 运行模型（两边相同）

```text
用户本机主题工具
    │  启动官方 Codex + 本机 CDP
    ▼
官方 Codex Desktop（不改 asar / 签名）
    │  注入 CSS + 装饰 DOM
    ▼
仍用原生侧栏 / 输入框 / 建议卡
```

## 路径速查

### macOS

| 用途 | 路径 |
|------|------|
| 源码（本整理包） | `Codex-Dream-Skin/macos/` |
| 原生菜单栏应用 | `/Applications/Codex Dream Skin.app` |
| 安装后引擎 | `~/.codex/codex-dream-skin-studio` |
| 状态 / 日志 | `~/Library/Application Support/CodexDreamSkinStudio` |
| Codex 配置 | `~/.codex/config.toml`（仅外观相关项可能被改，可恢复） |

### Windows

| 用途 | 路径 |
|------|------|
| 源码（本整理包） | `Codex-Dream-Skin/windows/` |
| 托盘应用 | `Codex Dream Skin.exe`（安装版或便携版） |
| 主题 / 状态 / 日志 | `%LOCALAPPDATA%\CodexDreamSkinStudio` |
| Codex 配置 | `%USERPROFILE%\.codex\config.toml` |
| 默认 CDP 端口 | 从 `9341` 起动态选择空闲回环端口 |

## 能力矩阵

| 功能 | macOS | Windows |
|------|:-----:|:-------:|
| 原生平台应用 | ✅ 菜单栏 / DMG | ✅ 托盘 / EXE |
| 安装脚本 | ✅ | ✅ |
| 启动 + 注入 | ✅ | ✅ |
| 一键恢复 | ✅ | ✅ |
| 实机 verify / 截图 | ✅ | ✅ |
| 用户选图定制 | ✅ | ✅ |
| 完整主题工作室 | ✅ | ✅ |
| 布局 / 配色 / 历史热切换 | ✅ | ✅ |
| 主题包导入 / 导出 | ✅ | ✅ |
| 官方应用发现 / 校验 | ✅ 签名校验 | ✅ Store 包动态发现 |
| 客户部署提示词 | ✅ | ❌（可用 Mac 文案改写） |
| 用户发行包 | ✅ 通用 DMG | ✅ 安装版 / 便携版 EXE |
| 自动发布安装包 | ✅ 标签构建 DMG | ✅ 标签构建安装版 / 便携版 EXE |

## 不要放进这个目录的东西

- API Key、`.codex/auth.json`
- 中转站密钥、服务器私钥
- 含客户隐私的实机截图（若要公开）
