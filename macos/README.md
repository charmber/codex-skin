# Codex Dream Skin Studio

Unofficial macOS theme studio for the **official Codex Desktop** app.

Turn an image you like into a Codex theme: a dedicated home banner, a low-noise task background, and frosted content layers — while **keeping native sidebar, suggestion cards, project picker, task content, menus, and composer** fully interactive.

This project injects through **local loopback CDP**. It does **not** modify the official `.app`, `app.asar`, or code signature.

> Not affiliated with OpenAI. Codex is a trademark of its respective owners.

## Requirements

- macOS 13 or newer
- Official Codex Desktop installed and launched at least once (`~/.codex/config.toml` exists)
- No global Node.js install required (uses Codex’s signed bundled Node after validation)

## Install from DMG

1. Download `Codex-Dream-Skin-v*.dmg` from [GitHub Releases](https://github.com/charmber/codex-skin/releases).
2. Open the DMG and drag **Codex Dream Skin** into **Applications**.
3. Open the app once. Look for `Skin` in the top-right menu bar.
4. Choose **初始化主题引擎**, then **应用皮肤**.
5. Optionally enable **登录时启动** from the menu.

The app runs only in the menu bar and has no Dock icon. macOS does not allow a DMG to execute an app merely because it was mounted or copied, so the first manual launch is required.

## Build a DMG from source

```bash
# From the repository root. Produces a universal arm64 + x86_64 DMG.
./macos/scripts/build-dmg.sh --unsigned

# Output:
# macos/release/Codex-Dream-Skin-v<VERSION>.dmg
```

Local ad-hoc builds are suitable for development but trigger Gatekeeper warnings on other Macs. Public releases should use a Developer ID Application identity and Apple notarization:

```bash
export CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_KEYCHAIN_PROFILE='codex-dream-skin-notary'
./macos/scripts/build-dmg.sh --identity "$CODESIGN_IDENTITY" --notarize
```

`build-dmg.sh` also accepts App Store Connect credentials through `APPLE_API_KEY_PATH`, `APPLE_API_KEY_ID`, and `APPLE_API_ISSUER_ID`.

## Automated GitHub release

The workflow at `.github/workflows/macos-release.yml` builds and publishes a notarized DMG when a tag such as `v1.5.0` matches `macos/VERSION`.

Configure these GitHub Actions secrets before pushing a release tag:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `MACOS_CODESIGN_IDENTITY` | Full `Developer ID Application: ... (TEAMID)` identity |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | Complete contents of the API key `.p8` file |

Then update `VERSION` and `CHANGELOG.md`, commit the release, and push the matching tag. Never commit certificates, API keys, or passwords.

## Legacy script install

The previous scripts remain available for CLI use and older macOS versions:

```bash
cd macos

# Optional static checks
./tests/run-tests.sh

# Install to the stable path and create Desktop launchers
./scripts/install-dream-skin-macos.sh --no-launch

# Customize with your image (Finder picker if you omit flags)
~/.codex/codex-dream-skin-studio/scripts/customize-theme-macos.sh

# Start / re-apply, verify, or restore via Desktop:
#    Codex Dream Skin.command
#    Codex Dream Skin - Customize.command
#    Codex Dream Skin - Verify.command
#    Codex Dream Skin - Restore.command

# Optional legacy menu bar for macOS 12 or older (requires SwiftBar)
./Install\ Menu\ Bar.command
```

Install location after step 2:

| Item | Path |
| --- | --- |
| Engine | `~/.codex/codex-dream-skin-studio` |
| State / logs / user images | `~/Library/Application Support/CodexDreamSkinStudio` |
| Theme backup | under Application Support (`theme-backup.json`) |

## Switch the skin-07 palette and background

The native `Skin` menu keeps these choices independent:

- `配色主题` changes the interface colors and shell. Choose `初音未来 · 未来青`, `演出夜`, or `樱花舞台`.
- `背景图片` changes only the pure image. It keeps the selected palette.
- `换一张图…` imports another image, saves it in the local image library, and keeps the selected palette.
- `调整阅读区磨砂与透明度…` sets task-panel opacity from 0–100 and backdrop blur from 0–40 px.
- `自定义顶部文字…` edits the top-left title/subtitle and top-right status text; an empty value hides that line.
- `历史组合` is retained for themes saved by older versions; choosing one restores that old combined snapshot.

Reading-panel and header-text preferences are independent from palettes and backgrounds, so later switches keep your values.

Changes normally hot-apply in a few seconds. A full Codex restart is only used when the loopback CDP session is unavailable.

CLI examples:

```bash
# Change colors, keep background
~/.codex/codex-dream-skin-studio/scripts/switch-palette-macos.sh --id miku-aqua

# Change background, keep colors
~/.codex/codex-dream-skin-studio/scripts/load-image-theme-macos.sh \
  --from-library "luna.JPG" --name "Luna"

# Adjust task reading panel, keep palette/background
~/.codex/codex-dream-skin-studio/scripts/configure-reading-panel-macos.sh \
  --opacity 68 --blur 18

# Customize top header copy
~/.codex/codex-dream-skin-studio/scripts/customize-header-text-macos.sh \
  --title "我的初音工作台" --subtitle "MIKU DEV STAGE" --status "READY TO CODE"
```

## Customer ZIP (legacy packaging)

To build the “double-click install” folder layout for non-git users:

```bash
./scripts/build-client-release.sh "$HOME/Desktop/Codex 主题编辑器.zip"
```

That ZIP contains a visible installer plus a hidden `.codex-dream-skin-studio` engine. Prefer the DMG for macOS 13 or newer. Do not ship only CSS/images.

## How it works (security boundary)

1. The menu bar app atomically deploys its bundled engine to the stable user path.
2. Discover `com.openai.codex` and validate signature / Team ID / arch / bundled Node.
3. Start Codex with CDP bound to `127.0.0.1` only.
4. Accept the debug port only when it belongs to Codex (or a legitimate child).
5. Inject only into expected `app://` renderer targets.
6. Keep a small injector alive across reloads and route changes.
7. Restore stops the injector only when PID, path, and start time match the recorded job.

The menu bar app uses direct executable paths and argument arrays when calling the engine. It does not pass theme names or image paths through `shell -c`.

CDP is powerful and unauthenticated on loopback. Prefer Restore when you are done theming.

## Image guidelines

- PNG / JPEG / HEIC / TIFF / WebP (macOS readable)
- Source ≤ 50 MB; prepared file ≤ 16 MB
- Wide images work best (width ≥ 2000 px recommended)
- Keep the left side relatively calm for native home titles
- Image is banner + background only — never a full-window fake UI overlay

CLI example:

```bash
~/.codex/codex-dream-skin-studio/scripts/customize-theme-macos.sh \
  --image "/path/to/image.png" \
  --name "My theme" \
  --accent "#7cff46" \
  --secondary "#36d7e8" \
  --highlight "#642a8c"
```

Reset to the bundled abstract demo:

```bash
~/.codex/codex-dream-skin-studio/scripts/customize-theme-macos.sh --reset-demo
```

## License

MIT — see `LICENSE`. Additional notices in `NOTICE.md` (trademarks, demo asset, runtime Node).

## Maintainer

- [charmber](https://github.com/charmber) · `charmber@qq.com`
- Repository: <https://github.com/charmber/codex-skin>

## What this is not

- Not an OpenAI product and not a fork of Codex source
- Not a way to patch or rebrand the official binary
- Not a Windows build (see `../windows/`)
- Not an API proxy: theming does not change model providers or API keys

If you use a third-party API relay, configure it separately — keep theme install and API config as two explicit steps.
