# Codex Dream Skin 主题包规范

从 `1.10.0` 开始，Codex Dream Skin 把可信渲染器与用户主题彻底分开：

- `renderer/` 是随应用发布的渲染层，包含 DOM 适配、CSS、布局模块和渲染器素材。
- `themes/` 与用户主题库是主题层，只包含声明式 JSON、背景、预览和可选头像。
- `.cds-theme.zip` 是可导入、可导出的便携主题包，不允许携带或执行 JS、CSS、Shell 等代码。

因此，普通用户安装一次 Codex Dream Skin 后，只需导入主题 ZIP 即可添加一个完整主题。主题需要新布局能力时，应先升级应用里的渲染器，而不是在主题包中夹带代码。

## 最快使用方法

### 导出当前主题

1. 点击 macOS 菜单栏的 `Skin`。
2. 选择 `导出当前主题...`。
3. 保存为 `主题名.cds-theme.zip`。

导出的文件包含当前主题配置、背景和可选头像，可以直接发给其他已安装 `1.10.0` 或更新版本的用户。

### 导入主题

1. 点击 macOS 菜单栏的 `Skin`。
2. 选择 `导入主题包...`。
3. 选择 `.cds-theme.zip` 文件。

应用会先检查路径、符号链接、文件数量、解压体积、JSON 字段、素材引用、渲染 API 和最低应用版本。校验通过后，主题会原子写入主题库并立即应用；同一个 `id` 再次导入时，会在完整校验通过后替换旧版本。

## 压缩包目录

推荐让下列文件直接位于 ZIP 根目录。导入器也兼容外面多包一层同名文件夹的 ZIP。

```text
my-neon-stage.cds-theme.zip
├── manifest.json          # 包身份、版本和渲染器兼容性
├── theme.json             # 完整主题配置
├── background.webp        # 必需，主背景
├── avatar-user.png        # 可选，用户头像
├── avatar-assistant.png   # 可选，Codex 头像
├── README.md              # 可选，主题说明
└── LICENSE.txt            # 可选，素材许可
```

所有主题图片必须和两个 JSON 位于同一层，JSON 中只能写文件名，不能写子目录、绝对路径或 `../`。主题包总解压体积不得超过 32 MB；ZIP 不得超过 64 MB；背景/预览单文件不得超过 16 MB；每张头像不得超过 4 MB。

## manifest.json

完整示例：

```json
{
  "format": "codex-dream-skin-theme",
  "formatVersion": 1,
  "id": "my-neon-stage",
  "name": "我的霓虹舞台",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "青绿霓虹工作台主题",
  "license": "CC-BY-4.0",
  "homepage": "https://example.com/my-neon-stage",
  "renderer": {
    "apiVersion": 1,
    "minEngineVersion": "1.10.0",
    "layoutId": "stage"
  },
  "theme": "theme.json",
  "preview": "background.webp"
}
```

字段说明：

| 字段 | 必需 | 写法 |
| --- | --- | --- |
| `format` | 是 | 固定为 `codex-dream-skin-theme` |
| `formatVersion` | 是 | 当前固定为整数 `1` |
| `id` | 是 | 包的稳定 ID；小写字母/数字开头，只用小写字母、数字、`.`、`_`、`-`，最长 80 个字符 |
| `name` | 是 | 展示名称，最长 80 个字符 |
| `version` | 是 | 主题自身的语义版本，例如 `1.0.0` |
| `author` | 否 | 作者或团队，最长 120 个字符 |
| `description` | 否 | 简介，最长 240 个字符 |
| `license` | 否 | 主题与素材许可证标识 |
| `homepage` | 否 | 主题主页或来源链接 |
| `renderer.apiVersion` | 是 | 当前为 `1`；必须与应用渲染 API 一致 |
| `renderer.minEngineVersion` | 是 | 可运行此主题的最低 Codex Dream Skin 版本 |
| `renderer.layoutId` | 是 | 必须与 `theme.json` 的 `layoutId` 相同，当前内置 `stage`、`qq-classic` |
| `theme` | 是 | 固定为 `theme.json` |
| `preview` | 否 | ZIP 根目录中的 PNG/JPEG/WebP 文件名；可复用背景图 |

`manifest.id` 必须和 `theme.json` 的 `id` 完全一致。

## theme.json

这是一个可直接导入的完整示例：

```json
{
  "schemaVersion": 1,
  "id": "my-neon-stage",
  "name": "我的霓虹舞台",
  "paletteId": "neon-aqua",
  "paletteName": "霓虹青",
  "backgroundName": "夜间城市",
  "layoutId": "stage",
  "visualStyle": "portal",
  "brandSubtitle": "MY CODEX STAGE",
  "tagline": "把灵感写成可以运行的代码。",
  "projectPrefix": "选择项目 · ",
  "projectLabel": "选择项目",
  "statusText": "STAGE ONLINE",
  "quote": "MAKE SOMETHING WONDERFUL",
  "image": "background.webp",
  "avatars": {
    "user": "avatar-user.png",
    "assistant": "avatar-assistant.png"
  },
  "effects": {
    "taskPanelOpacity": 0.76,
    "taskPanelBlur": 14
  },
  "headerText": {
    "title": "我的工作台",
    "subtitle": "NEON STAGE",
    "status": "READY"
  },
  "layoutComponents": {
    "retroHeader": true,
    "toolbar": true,
    "threePane": true,
    "autoOpenSummary": true,
    "companion": true,
    "profileCard": true,
    "homePet": true,
    "minWidth": 1180,
    "rightWidth": 300,
    "windowTitle": "Codex 2007",
    "profileName": "",
    "profileStatus": "在线",
    "companionTitle": "Codex 伙伴",
    "companionStatus": "在线 · 随时待命"
  },
  "colors": {
    "background": "#071116",
    "panel": "#0b1a20",
    "panelAlt": "#10272c",
    "accent": "#39c5bb",
    "accentAlt": "#68e3d9",
    "secondary": "#58c9ee",
    "highlight": "#ff6f91",
    "text": "#f2fff7",
    "muted": "#a7c2ba",
    "line": "rgba(57, 197, 187, 0.30)"
  }
}
```

主要字段：

| 分组 | 字段 | 说明 |
| --- | --- | --- |
| 身份 | `schemaVersion` / `id` / `name` | `schemaVersion` 当前为 `1`；`id` 与 manifest 相同 |
| 配色 | `paletteId` / `paletteName` | 配色的机器 ID 和展示名 |
| 布局 | `layoutId` / `visualStyle` | 选择渲染器已有布局和该布局中的视觉风格 |
| 素材 | `image` / `avatars.*` | ZIP 根目录中的图片文件名；头像可写 `null` 或省略 |
| 文案 | `brandSubtitle` 等 | 首页、项目入口、状态和引用文字；空字符串表示隐藏 |
| 阅读区 | `effects.taskPanelOpacity` | `0` 到 `1`，例如 `0.76` 表示 76% |
| 阅读区 | `effects.taskPanelBlur` | `0` 到 `40`，单位为 px |
| 顶部文字 | `headerText.*` | 可写字符串、空字符串或 `null` |
| 布局组件 | `layoutComponents.*` | 经典蓝布局的开关、文字和尺寸；其他布局可以省略 |
| 颜色 | `colors.*` | 10 个颜色全部必需；支持六位 Hex 和 `rgb()` / `rgba()` |

机器可读约束位于：

- `schemas/theme-package-manifest.schema.json`
- `schemas/theme.schema.json`

## 生成主题包

首选方式是用主题工作室编辑，然后从菜单栏导出。这样字段、图片压缩和兼容版本会自动生成。

命令行导出当前主题：

```bash
~/.codex/codex-dream-skin-studio/scripts/export-theme-package-macos.sh \
  --output "$HOME/Desktop/My-Theme.cds-theme.zip"
```

手工制作时，先按上面的目录建立文件，再校验目录：

```bash
node macos/scripts/theme-package.mjs validate --directory "/path/to/my-theme"
```

校验通过后，在主题目录内压缩，避免把父级开发目录和 macOS 扩展属性带入包中：

```bash
cd "/path/to/my-theme"
/usr/bin/zip -X -r "$HOME/Desktop/My-Theme.cds-theme.zip" .
```

最后再次校验成品 ZIP：

```bash
node macos/scripts/theme-package.mjs validate \
  --archive "$HOME/Desktop/My-Theme.cds-theme.zip"
```

## 命令行导入

导入并应用：

```bash
~/.codex/codex-dream-skin-studio/scripts/import-theme-package-macos.sh \
  --file "$HOME/Downloads/My-Theme.cds-theme.zip"
```

只加入主题库，不改变当前主题：

```bash
~/.codex/codex-dream-skin-studio/scripts/import-theme-package-macos.sh \
  --file "$HOME/Downloads/My-Theme.cds-theme.zip" \
  --library-only
```

导入后的主题位于：

```text
~/Library/Application Support/CodexDreamSkinStudio/themes/<manifest.id>/
```

## 安全与兼容规则

- 主题包不能包含 `.js`、`.mjs`、`.css`、`.sh`、可执行文件、符号链接、子目录或未被引用的文件。
- `docs/images/gallery/*` 是展示合成图，不应直接当纯背景打包；主题背景应来自主题工作室、`images/` 或合法持有的原图。
- 导入不会修改官方 Codex `.app`、`app.asar`、代码签名、API Key、Base URL 或模型配置。
- 渲染仍只通过 `127.0.0.1` 回环 CDP 完成。主题 ZIP 只改变主题层，不扩大 CDP 边界。
- 主题包引用的 `layoutId` 必须由当前 `renderer/manifest.json` 提供；不支持的布局会直接拒绝，不会降级成另一个布局。
- 若未来主题格式或渲染 API 升级，应提高 `formatVersion` 或 `renderer.apiVersion`；旧应用会明确拒绝不兼容包，而不是尝试执行未知内容。
