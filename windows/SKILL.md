---
name: codex-dream-skin
description: Apply, launch, verify, repair, update, or restore a full decorative skin for the Windows Codex desktop app. Use when the user asks for a Codex theme that goes beyond official color settings, wants the pink-purple Dream/Fiona-style interface, needs the skin reapplied after a Codex update, or needs a safe rollback without modifying WindowsApps or app.asar.
---

# Codex Dream Skin

Apply a reversible renderer skin through Chromium DevTools Protocol while launching the official Store-installed Codex executable. The 1.11.2+ Windows tray EXE is the primary user entry point; PowerShell scripts remain for legacy single-theme compatibility. Never replace or take ownership of files under `WindowsApps`.

## Workflow

1. Prefer the GitHub Release EXE documented in `README.md`. Open Theme Studio from the tray icon and use **保存并应用**.
2. If Codex is already running without CDP, restart it only after the app's explicit confirmation prompt.
3. Use layout, palette, background, history, import/export, pause, and restore actions from the tray menu. User state lives under `%LOCALAPPDATA%\CodexDreamSkinStudio`.
4. For legacy script QA, run `scripts/start-dream-skin.ps1` and then `scripts/verify-dream-skin.ps1 -ScreenshotPath <absolute-path>`.
5. Inspect real home and task screens against `references/qa-inventory.md`; never sign off from the Theme Studio preview alone.

## Guardrails

- Preserve the official executable, package signature, user threads, pets, plugins, and authentication state.
- Do not use the full reference screenshot as a fake whole-window overlay. It is only a cropped hero/polaroid asset; all controls remain live Codex controls.
- Keep the reference image confined to the single top banner and decorative crop. Keep the cards below it as native Codex suggestion buttons with native labels/icons.
- Attach the "选择项目" treatment to Codex's real project-selector toolbar and keep the current project button clickable; never draw a disconnected replacement.
- Keep decorative layers `pointer-events: none` and keep real buttons, navigation, and composer above them.
- On app updates, rerun install and launch; the scripts discover the current Appx package dynamically.
- If port `9335` is occupied, choose another port consistently for start, verify, and restore.
- Keep the injection daemon running for navigation/reload resilience. EXE state and logs live under `%LOCALAPPDATA%\CodexDreamSkinStudio`; `%LOCALAPPDATA%\CodexDreamSkin` is legacy-script state.
- Treat imported `.cds-theme.zip` files as declarative data only. Do not relax the EXE's path, size, symlink, unreferenced-file, or executable-content checks.
- Do not force `appearanceTheme` during install; renderer CSS handles the active light/dark shell.

## Resources

- `scripts/injector.mjs`: CDP connection, renderer injection, verification, screenshot, and removal.
- `assets/dream-skin.css`: full visual layer.
- `assets/renderer-inject.js`: idempotent DOM integration and cleanup.
- `assets/dream-reference.png`: user-provided visual reference used only in cropped decorative regions.
- `references/qa-inventory.md`: required functional and visual signoff coverage.
- `references/runtime-notes.md`: troubleshooting and update behavior.
- `app/`: Electron tray app, Theme Studio, package validation, tests, and EXE build configuration.
- `README.md`: current Windows installation, storage, build, and security documentation.
- `CHANGELOG.md`: user-facing Windows release notes.
