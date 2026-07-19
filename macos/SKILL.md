---
name: codex-dream-skin-studio
description: Install, customize, launch, verify, repair, update, or restore Codex Dream Skin Studio on macOS. Use when a user wants to turn a personal image into a Codex banner and task background while preserving the native interface, or needs safe CDP theme troubleshooting and rollback.
compatibility: macOS, official Codex Desktop app, signed bundled Node.js 20 or newer
---

# Codex Dream Skin Studio

This file is an optional Codex capability entry. The delivery is a complete standalone project; users do not need to install it as a Skill.

## Workflow

1. On macOS 13 or newer, install `Codex Dream Skin.app` from the DMG, open it once, and choose `初始化主题引擎` from the menu bar. The `.command` installer remains a compatibility fallback.
2. Choose `打开主题工作室` from the menu bar to create a full theme, including its background, complete palette, copy, and reading effects. Use `打开主题商店` to browse <https://skin.beanplay.cn>, use `导入主题包` / `导出当前主题` for portable `.cds-theme.zip` packages, and `快速换背景图` only for a simple image replacement.
3. Verify the live result with `Verify Codex Dream Skin.command`. A pass requires a visible native sidebar and composer, no horizontal overflow, non-interactive decoration, and—on the home route—a real banner, native cards, and project selector.
4. Restore the official appearance from the menu bar or with `Restore Codex Dream Skin.command`.

## Guardrails

- Never modify the official `.app`, `app.asar`, or its code signature.
- Use the official Codex app's signed Node.js runtime only after validating its signature, Team ID, architecture, and minimum version.
- Bind CDP to loopback, verify that the listener belongs to Codex, and reject non-Codex renderer targets.
- Preserve all native cards, navigation, project selectors, task content, composer controls, and keyboard focus.
- Keep decoration at `pointer-events: none`.
- Require explicit authorization before restarting an already-running Codex instance.
- Stop an injector only when its recorded PID, executable, command line, and start time all match.

## Key resources

- `README.md`: user installation and customization guide.
- `THEME_PACKAGE.md`: portable theme package format, field reference, and authoring guide.
- `scripts/injector.mjs`: CDP connection, injection, removal, verification, and screenshots.
- `renderer/manifest.json`: trusted renderer API and built-in layout registry.
- `renderer/layouts/`: trusted styles, DOM integration, and renderer-only assets.
- `themes/`: declarative built-in themes; portable theme packages use the same data boundary.
- `scripts/doctor-macos.sh`: signed-runtime, payload, and optional live-session self-check.
- `references/qa-inventory.md`: release and visual acceptance criteria.
