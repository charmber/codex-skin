# Codex Dream Skin · 项目记录

> 本地归档说明。面向维护者，不是用户安装手册。  
> 仓库首页：[`../README.md`](../README.md)（中文）· [`../README.en.md`](../README.en.md)（English）  
> GitHub：https://github.com/charmber/codex-skin
> 维护者：[`charmber`](https://github.com/charmber) · `charmber@qq.com`

---

## 1. 它是什么

**Codex Dream Skin** 是给 **OpenAI Codex 桌面端** 用的**外部主题 / 换肤**方案：

- 本机 **CDP** 注入 CSS + 装饰 DOM
- **不修改**官方 `.app` / `app.asar` / WindowsApps / 代码签名
- 侧栏、建议卡、项目选择、输入框仍是**原生可点控件**（不是整窗假截图）
- 可换图、可一键恢复
- **不会**静默改写 API Key、Base URL 或模型供应商配置

非 OpenAI 官方产品。

---

## 2. 项目状态

| 阶段 | 说明 |
|------|------|
| 跨平台 | 按平台拆成 `macos/`、`windows/`，提供对应安装与运行入口 |
| 安全模型 | 通过本机回环 CDP 注入，不改官方应用包、签名或模型供应商配置 |
| 本地美化 | Mac 提供原生菜单栏应用与 DMG；引擎装在 `~/.codex/codex-dream-skin-studio`，支持主题、背景与阅读区配置 |
| 图库 | `docs/images/gallery/skin-01`～`08`；粉系定制 → 财神打工 → 红白科幻… |
| i18n | 默认中文 `README.md`，英文 `README.en.md`，顶部互链 |

本地曾用过 `8765` 静态预览与临时 injector；**发布后不要求**常驻这两个进程。桌面快捷方式指向已安装引擎，不依赖本仓库路径。

---

## 3. 架构（两边相同）

```text
用户本机主题工具（原生菜单栏应用 / 本仓库脚本 / 已安装引擎）
    │  启动官方 Codex + 本机 CDP（127.0.0.1）
    ▼
官方 Codex Desktop（不改 asar / 签名）
    │  注入 CSS + 装饰 DOM
    ▼
原生侧栏 / 输入框 / 建议卡 + 主题外观
```

更细的平台路径见 [`platforms.md`](./platforms.md)。

---

## 4. 仓库结构

```text
Codex-Dream-Skin/
├── README.md              # 默认中文
├── README.en.md           # English
├── docs/
│   ├── PROJECT.md         # 本文件（项目记录）
│   ├── platforms.md       # Win/Mac 路径与能力矩阵
│   ├── promo-copy.md      # 宣传文案（朋友圈等，注意肖像/IP）
│   └── images/
│       └── gallery/       # README 效果图 skin-01…08
├── macos/                 # Mac 菜单栏应用、DMG 构建、脚本、资源、LICENSE、SKILL
└── windows/               # Windows PowerShell / 注入脚本
```

**安装后的运行位置（Mac，与仓库分离）：**

| 用途 | 路径 |
|------|------|
| 菜单栏应用 | `/Applications/Codex Dream Skin.app` |
| 引擎 | `~/.codex/codex-dream-skin-studio` |
| 状态 / 主题 | `~/Library/Application Support/CodexDreamSkinStudio` |
| 桌面启动器 | `~/Desktop/Codex Dream Skin*.command` → 指向上面的引擎脚本 |

Windows 状态目录见 `platforms.md`（`%LOCALAPPDATA%\CodexDreamSkin`）。

---

## 5. Git / 移动目录说明

- **远程**：`origin` → `https://github.com/charmber/codex-skin.git`
- **分支**：`main`
- **整夹移动本地路径**（例如从一个工作目录挪到另一个工作目录）：
  - **不影响** `.git` 历史、commit、remote
  - **不影响** GitHub 上的仓库
  - 只需用 `mv` 移动整个含 `.git` 的目录；之后在新路径里 `git status` 即可
  - 若 IDE / 终端仍开着旧路径工作区，需重新打开新路径

桌面 `.command` 与 `~/.codex/...` **不依赖**本仓库磁盘位置，移动开源目录后主题安装仍可用。

---

## 6. 安全与合规边界

1. CDP **仅** `127.0.0.1`，主题运行期勿跑来路不明的本机程序  
2. 不改官方安装目录与签名  
3. **禁止**安装脚本静默写入第三方 Base URL / Key  
4. 效果图含人物 / IP 时仅作主题示意；商用再分发需自行确认肖像与商标  
5. 宣传文案见 `promo-copy.md`（避免未授权商业化表述）

---

## 7. 常用维护动作

| 动作 | 说明 |
|------|------|
| 换图库图 | 替换 `docs/images/gallery/skin-XX.jpg`，同步改 README 两份 caption |
| 本地构建 DMG | `./macos/scripts/build-dmg.sh --unsigned` |
| 正式发版 | 更新 `macos/VERSION` / `CHANGELOG.md`，推送匹配的 `vX.Y.Z` 标签触发签名、公证与 GitHub Release |
| Mac 本机主题 | 改 `~/.codex/codex-dream-skin-studio` 的 CSS/inject；与 GitHub 源码可不同步，属本机实验位 |

---

## 8. 相关但不在本仓

| 项 | 说明 |
|----|------|
| 本机已装引擎 | `~/.codex/codex-dream-skin-studio` |

---

*最后更新：随仓库提交维护。有架构变更时优先改本文件与 `platforms.md`。*
