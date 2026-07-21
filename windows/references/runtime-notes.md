# Runtime notes

- The tray EXE discovers the current Store-installed `ChatGPT.exe`, launches it with an explicit `--remote-debugging-address=127.0.0.1`, and injects through CDP.
- Production starts searching for an available loopback port at `9341`; the selected port is shared by apply, verify, pause, and restore operations.
- If Codex is already running without CDP, the tray app asks before restarting. It never silently terminates the user's session.
- The injector polls verified Codex renderer targets and reinjects after document loads and route changes.
- `%LOCALAPPDATA%\CodexDreamSkinStudio\state.json` records the port and watcher PID. Only a PID whose command line still contains this engine's `injector.mjs --watch` is eligible for termination.
- Themes, history, backgrounds, and logs remain under `%LOCALAPPDATA%\CodexDreamSkinStudio`; uninstalling the EXE does not delete them by default.
- Store updates are supported because the launcher queries `Get-AppxPackage OpenAI.Codex` on each full launch instead of persisting a versioned `WindowsApps` path.
- `scripts/*.ps1` and `%LOCALAPPDATA%\CodexDreamSkin` describe the legacy single-theme compatibility path, not the current EXE runtime.
