# Codex Dream Skin

<p align="center">
  <a href="./README.md">中文</a> · <strong>English</strong>
</p>

<p align="center">
  <strong>Give Codex a face that breathes.</strong><br>
  External themes for the Codex desktop app · Local CDP inject · No official package mutation
</p>

<p align="center">
  One image, one mood · Code with atmosphere
</p>

<p align="center">
  Unofficial. Does not modify <code>.app</code> / <code>app.asar</code> / WindowsApps.
</p>

## Gallery

One image, one mood. Real theme previews you can ship:

<p align="center">
  <img src="docs/images/gallery/skin-01.jpg" alt="Pink Custom" width="900"><br>
  <sub>Pink Custom</sub>
</p>

<p align="center">
  <img src="docs/images/gallery/skin-02.jpg" alt="God of Wealth" width="900"><br>
  <sub>God of Wealth</sub>
</p>

<p align="center">
  <img src="docs/images/gallery/skin-03.jpg" alt="Red-White Sci-Fi" width="900"><br>
  <sub>Red-White Sci-Fi</sub>
</p>

## Theme Studio in 1.6.0

Open `Skin → 打开主题工作室…` from the menu bar to create a complete theme. Continue from the active theme or choose `新建主题` to start with a clean configuration:

- Name the theme, choose and preview its associated background, and select the Portal or Future Stage shell
- Customize all ten interface colors across the page, panels, accents, text, and borders
- Edit home copy, project actions, status text, theme quote, and top-header labels
- Tune task-panel opacity and backdrop blur
- Save a reusable theme snapshot, with optional immediate hot apply to the current Codex session

### Color Palette

The palette editor covers the page background, primary and secondary panels, two accent colors, secondary and highlight colors, primary and muted text, plus borders and separators. Color swatches use the native macOS picker, and the border color supports transparency.

<p align="center">
  <img src="docs/Color_matching.jpg" alt="Codex Dream Skin color palette editor" width="900"><br>
  <sub>Complete color palette with the associated background preview</sub>
</p>

### Theme Copy

Configure the brand subtitle, home description, project prefix and button, status label, and theme quote independently. Optional copy can be left empty when it should stay hidden.

<p align="center">
  <img src="docs/Theme_copywriting.jpg" alt="Codex Dream Skin theme copy editor" width="900"><br>
  <sub>Home and project copy settings</sub>
</p>

### Interface Effects

The effects panel keeps task-reading opacity, backdrop blur, the top-left title and subtitle, and the top-right status text in one place.

<p align="center">
  <img src="docs/Interface_effect.jpg" alt="Codex Dream Skin interface effects editor" width="900"><br>
  <sub>Reading-panel effects and top-header text</sub>
</p>


## What it does

- **Real UI** — Sidebar, cards, project picker, and input stay native. Not a fake full-window screenshot.
- **Complete theme studio** — Create themes with an associated background preview, all ten interface colors, home/header copy, and reading effects.
- **Reusable themes** — Every save creates a complete theme snapshot that can be loaded again from the menu.
- **Quick background swap** — Drop in a new image without losing the selected palette.
- **Restorable** — One-click restore to the stock look.
- **Safer path** — Local-loopback CDP inject only. No official binary or signature changes.

## Quick start

On macOS 13 or newer, download the DMG from [GitHub Releases](https://github.com/charmber/codex-skin/releases), drag the app into Applications, and open it once. The native `Skin` menu then appears in the menu bar with no SwiftBar dependency. Current releases are unsigned and not notarized; Control-click the app and choose **Open** on first launch. Do not disable Gatekeeper globally.

Build a universal DMG from source:

```bash
./macos/scripts/build-dmg.sh --unsigned
```

Platform scripts remain available as compatibility entry points.

| Platform | Dir | Entry |
|------|------|------|
| Apple Silicon / Intel Mac | [`macos/`](./macos/) | `Codex Dream Skin.app` from the DMG; `.command` scripts remain available |
| Windows | [`windows/`](./windows/) | `scripts/install-dream-skin.ps1` → `start-dream-skin.ps1` |

More detail:

- Mac: [`macos/README.md`](./macos/README.md)
- Windows: [`windows/SKILL.md`](./windows/SKILL.md)
- Paths: [`docs/platforms.md`](./docs/platforms.md)
- Project notes: [`docs/PROJECT.md`](./docs/PROJECT.md)

## Safety

- CDP binds `127.0.0.1` only — avoid untrusted local processes while the theme runs.
- Does not touch the official install directory or code signature.
- **Never** rewrites API Key / Base URL; relay and theme stay separate.

## License

- See [`macos/LICENSE`](./macos/LICENSE) (MIT) and [`macos/NOTICE.md`](./macos/NOTICE.md)
- Unofficial; Codex and related rights belong to their owners.
- People / IP art in previews is illustrative only — clear rights before commercial redistribution.

## Maintainer

- [charmber](https://github.com/charmber) · `charmber@qq.com`
- Repository: <https://github.com/charmber/codex-skin>

---

Star it, pick a look, and make Codex yours for today.
