# Codex Skin Codex皮肤

<p align="center">
  <strong>中文</strong> · <a href="./README.en.md">English</a>
</p>

<p align="center">
  <strong>给 Codex 桌面端换一张会呼吸的脸。</strong><br>
  外部主题 / 换肤工具 · 本机 CDP 注入 · 不改官方安装包
</p>

<p align="center">
  一张图，一种心情 · 写代码，也要有氛围感
</p>

<p align="center">
  非 OpenAI 官方产品。不修改 <code>.app</code> / <code>app.asar</code> / WindowsApps。
</p>

## 效果预览

一张图，一种心情。下面都是可落地的主题示意效果：

<p align="center">
  <img src="docs/images/gallery/skin-01.jpg" alt="暗黑系列" width="900"><br>
  <sub>暗黑系列</sub>
</p>

<p align="center">
  <img src="docs/images/gallery/skin-02.jpg" alt="樱花舞台" width="900"><br>
  <sub>樱花舞台</sub>
</p>

<p align="center">
  <img src="docs/images/gallery/skin-03.jpg" alt="未来青" width="900"><br>
  <sub>未来青</sub>
</p>

## 支持工具栏diy主题，背景，配色等功能
<img width="255" height="522" alt="image" src="https://github.com/user-attachments/assets/eaffad01-c246-4716-83be-0ac4356580a7" />


## 它能做什么

- **真·可交互**：侧栏、建议卡、项目选择、输入框都是原生控件，不是整窗假截图贴上去
- **配色与背景独立**：macOS 可在未来青、演出夜、樱花舞台之间切换 UI 配色，同时保留当前背景
- **可换图**：换一张喜欢的纯背景图，不会覆盖已经选择的配色主题
- **可调阅读区与顶部文字**：macOS 菜单可调整任务页磨砂/透明度，并自定义顶部品牌和状态文字
- **可恢复**：一键还原官方外观
- **相对安全**：本机回环 CDP 注入，不改官方二进制与签名

## 快速开始

macOS 13 或更高版本推荐直接从 [GitHub Releases](https://github.com/charmber/codex-skin/releases) 下载 DMG，拖入「应用程序」后首次打开一次，右上角会出现原生 `Skin` 菜单。无需安装 SwiftBar。当前 Release 为未经 Apple 公证的 unsigned 构建，首次启动请按住 Control 点击应用并选择「打开」；不要全局关闭 Gatekeeper。

**1.安装包安装：**

直接下载release的DMG文件，提示有风险，可以先右键，再点击打开即可安装

如提示这个为正常显示：
<img width="520" height="470" alt="image" src="https://github.com/user-attachments/assets/3af7303b-4a79-4e02-8519-39d220547367" />

从**设置**打开搜索**隐私与安全性**
<img width="220" height="125" alt="image" src="https://github.com/user-attachments/assets/06774080-4561-492c-8a6d-e0ffca70690a" />

然后选择仍要打开
<img width="723" height="625" alt="image" src="https://github.com/user-attachments/assets/918f1b06-6b46-4cba-8ff5-54805ee97f98" />
然后就可以在搜索栏搜索之后打开了
<img width="803" height="776" alt="image" src="https://github.com/user-attachments/assets/017c6454-7f31-4bf3-b951-a4421dbaf191" />


**2.从源码构建通用 DMG：**

```bash
./macos/scripts/build-dmg.sh --unsigned
```

**3.仓库内也保留了平台脚本作为兼容入口：**

| 平台 | 目录 | 入口 |
|------|------|------|
| Apple Silicon / Intel Mac | [`macos/`](./macos/) | DMG 中的 `Codex Dream Skin.app`；兼容入口为 `.command` 脚本 |
| Windows | [`windows/`](./windows/) | `scripts/install-dream-skin.ps1` → `start-dream-skin.ps1` |

更细的说明：

- Mac：[`macos/README.md`](./macos/README.md)
- Windows：[`windows/SKILL.md`](./windows/SKILL.md)
- 路径对照：[`docs/platforms.md`](./docs/platforms.md)
- 项目记录：[`docs/PROJECT.md`](./docs/PROJECT.md)

## 安全边界

- CDP 只绑 `127.0.0.1`，主题运行期间勿跑来路不明的本机程序
- 不修改官方安装目录与代码签名
- **不会**自动改写 API Key、Base URL 或模型供应商设置

## 许可与声明

- 见 [`macos/LICENSE`](./macos/LICENSE)（MIT）与 [`macos/NOTICE.md`](./macos/NOTICE.md)
- 非 OpenAI 官方产品；Codex 及相关权利归其权利人
- 效果图中的人物 / IP 形象仅作主题示意；商用或公开再分发请自行确认肖像权与商标授权

## 维护者

- [charmber](https://github.com/charmber) · `charmber@qq.com`
- 项目地址：<https://github.com/charmber/codex-skin>

---

Star 一下，然后挑一张图，把你的 Codex 变成今天想要的样子。
