# QA inventory

## User-visible claims

1. The Windows tray exposes apply, pause, Theme Studio, Theme Store, package import/export, layout/palette/background/history switches, restore, logs, and launch-at-login.
2. Theme Studio can save backgrounds, ten colors, copy, two avatars, reading effects, and Classic Blue layout components.
3. Stage and Classic Blue use isolated renderers; switching layouts removes the previous renderer before applying the next.
4. All real Codex controls remain interactive; previews and backgrounds are not whole-window screenshot overlays.
5. The skin survives route changes and renderer reloads while the injector watcher runs.
6. The official Store package and `app.asar` remain unchanged; restore removes injected DOM/CSS and can be repeated.

## Functional checks

- Home feature card: click one card and confirm the real composer is populated or the normal action occurs.
- Project selector: click the real project chip under the "选择项目" label and confirm the native project menu opens.
- Sidebar: open a real task, then return to New Task.
- Composer: type text, verify caret/readability, then clear it without sending.
- Reload: use CDP `Page.reload`, wait, and confirm the injection marker returns.
- Restore/reapply cycle: remove live skin, verify marker absent, apply again, verify marker present.
- Update resilience: resolve the current `OpenAI.Codex` Appx location dynamically; never store a versioned WindowsApps path.
- Hot switch: change layout, palette, and background while CDP is active; verify that Codex does not restart.
- Theme package: export, import into a clean state root, and reject traversal, duplicate/case-colliding, oversized, executable, and unreferenced entries.
- Theme Studio: save a theme with separate user/assistant avatars, reopen it from history, and verify all fields survive.

## Visual checks

- 1280x820 initial home: hero, four native cards, real project selector, and composer are all visible without horizontal scrolling.
- Narrower window: accept Codex's native responsive reduction to two or three suggestion cards; no essential control is covered and the polaroid may intentionally hide.
- Normal task: messages remain readable and composer does not overlap content.
- Inspect the sidebar, header, hero edges, card labels, composer controls, scrollbar, ribbon, and bottom-right decoration.
- Inspect both Stage and Classic Blue at wide and narrow widths; Classic Blue components must disable in Theme Studio while Stage is selected.
- Reject black/transparent sidebar artifacts, clipped cards, duplicated/disconnected project labels, rasterized native controls, weak contrast, or decorations intercepting clicks.

## Exploratory checks

- Start when the debug port is occupied: fail with a clear message or use a caller-selected port.
- Start after Codex updates: package discovery and injection still work without patching installed files.
