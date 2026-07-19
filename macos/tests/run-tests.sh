#!/bin/bash

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CODEX_NODE="/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node"
SKIP_RUNTIME_TESTS="${CODEX_DREAM_SKIN_SKIP_RUNTIME_TESTS:-false}"
CODEX_RUNTIME_AVAILABLE="false"
if [ "$SKIP_RUNTIME_TESTS" != "true" ] && [ -x "$CODEX_NODE" ]; then
  CODEX_RUNTIME_AVAILABLE="true"
fi
if [ -z "${NODE:-}" ]; then
  if [ "$CODEX_RUNTIME_AVAILABLE" = "true" ]; then
    NODE="$CODEX_NODE"
  else
    NODE="$(command -v node || true)"
  fi
fi
[ -x "$NODE" ] || { printf 'Node.js 20 or newer is required for static tests.\n' >&2; exit 1; }
NODE_MAJOR="$($NODE -p 'Number(process.versions.node.split(".")[0])')"
[ "$NODE_MAJOR" -ge 20 ] || { printf 'Node.js 20 or newer is required; found %s.\n' "$($NODE --version)" >&2; exit 1; }
export NODE
VERSION="$(/usr/bin/tr -d '[:space:]' < "$ROOT/VERSION")"
[ -n "$VERSION" ] || { printf 'VERSION is empty.\n' >&2; exit 1; }
PACKAGE_VERSION="$($NODE -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version)' "$ROOT/package.json")"
[ "$PACKAGE_VERSION" = "$VERSION" ] || {
  printf 'package.json version %s does not match VERSION %s.\n' "$PACKAGE_VERSION" "$VERSION" >&2
  exit 1
}

while IFS= read -r file; do /bin/bash -n "$file"; done < <(
  /usr/bin/find "$ROOT" -type f \( -name '*.sh' -o -name '*.command' \) \
    ! -path '*/release/*' -print
)
while IFS= read -r file; do "$NODE" --check "$file" >/dev/null; done < <(
  /usr/bin/find "$ROOT/scripts" "$ROOT/renderer" -type f \( -name '*.mjs' -o -name '*.js' \) -print
)

/bin/bash -c '
  . "$1/scripts/common-macos.sh"
  set +e
  started=$SECONDS
  run_with_deadline 1 /bin/sleep 30 >/dev/null 2>&1
  code=$?
  set -e
  [ "$code" -ne 0 ] && [ "$((SECONDS - started))" -lt 6 ]
' _ "$ROOT"

if /usr/bin/grep -R -n -E 'dream-skin-skin|DREAM_SKIN_SKIN|1\.0\.0-rc2' \
  "$ROOT/scripts" "$ROOT/renderer" >/dev/null; then
  printf 'Legacy release-candidate identifiers remain in runtime files.\n' >&2
  exit 1
fi
if /usr/bin/grep -R -n -E '(writeFile|rename|copyFile|rm).*app\.asar' "$ROOT/scripts" >/dev/null; then
  printf 'A runtime script appears to mutate app.asar.\n' >&2
  exit 1
fi

"$NODE" "$ROOT/scripts/injector.mjs" --check-payload >/dev/null

TMP="$(/usr/bin/mktemp -d /tmp/codex-dream-skin-tests.XXXXXX)"
trap '/bin/rm -rf "$TMP"' EXIT
/bin/mkdir -p "$TMP/home"
MENU_OUTPUT="$(HOME="$TMP/home" CODEX_DREAM_SKIN_ENGINE="$ROOT" /bin/bash "$ROOT/menubar/codex_dream_skin.10s.sh")"
/usr/bin/grep -F '布局主题' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '配色方案' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '导入主题包… | bash=' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '导出当前主题… | bash=' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '打开主题商店… | href="https://skin.beanplay.cn"' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '调整阅读区磨砂与透明度… | bash=' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '自定义顶部文字… | bash=' <<<"$MENU_OUTPUT" >/dev/null
LOCAL_STORE_MENU="$(HOME="$TMP/home" CODEX_DREAM_SKIN_ENGINE="$ROOT" \
  CODEX_DREAM_SKIN_STORE_URL="http://127.0.0.1:5173" \
  /bin/bash "$ROOT/menubar/codex_dream_skin.10s.sh")"
/usr/bin/grep -F '打开主题商店… | href="http://127.0.0.1:5173"' <<<"$LOCAL_STORE_MENU" >/dev/null
if /usr/bin/grep -F -- '-- 当前:' <<<"$MENU_OUTPUT" >/dev/null || \
   /usr/bin/grep -F -- '-- 可编辑左侧标题' <<<"$MENU_OUTPUT" >/dev/null; then
  printf 'SwiftBar preference actions were accidentally nested into disabled submenus.\n' >&2
  exit 1
fi
DIALOG_SELF_TEST="$(LC_ALL=C /usr/bin/osascript -l JavaScript \
  "$ROOT/scripts/reading-panel-dialog-macos.js" --self-test 68 18)"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (value.title !== "调整阅读区效果" || value.opacityLabel !== "阅读区不透明度" ||
      value.blurLabel !== "磨砂模糊强度" || value.output !== "68\t18") process.exit(1);
' "$DIALOG_SELF_TEST"
if /usr/bin/grep -R -n 'system attribute "DREAM_SKIN_' \
  "$ROOT/scripts/configure-reading-panel-macos.sh" "$ROOT/scripts/customize-header-text-macos.sh" >/dev/null; then
  printf 'Dynamic dialog copy must be passed as UTF-8 arguments, not environment attributes.\n' >&2
  exit 1
fi
/bin/mkdir -p "$TMP/theme"
/bin/cp "$ROOT/themes/builtin-miku-aqua/background.png" "$TMP/theme/background.png"
/bin/cp "$ROOT/themes/builtin-miku-aqua/background.png" "$TMP/theme/avatar-user.png"
/bin/cp "$ROOT/themes/builtin-miku-aqua/background.png" "$TMP/theme/avatar-assistant.png"
"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background.png --name '测试主题' --background-name '测试背景' --visual-style portal \
  --layout-id qq-classic --component-companion false --layout-window-title '测试 Codex 2007' \
  --user-avatar avatar-user.png --assistant-avatar avatar-assistant.png \
  --brand-subtitle 'TEST CODEX' --tagline '测试口号' --project-prefix '项目 · ' \
  --project-label '选择测试项目' --status-text 'TEST ONLINE' --quote 'TEST' \
  --background '#081018' --panel '#102030' --panel-alt '#183048' \
  --accent '#11aa55' --accent-alt '#44cc77' --secondary '#22bbcc' --highlight '#663399' \
  --text '#f5fff8' --muted '#99bbaa' --line 'rgba(17, 170, 85, 0.4)' \
  --task-panel-opacity 61 --task-panel-blur 19 \
  --header-title '测试工作台' --header-subtitle 'TEST STAGE' --header-status 'READY' >/dev/null
"$NODE" "$ROOT/scripts/theme-package.mjs" validate --directory "$TMP/theme" >/dev/null
THEME_ARCHIVE="$TMP/test-theme.cds-theme.zip"
"$NODE" "$ROOT/scripts/theme-package.mjs" export --source-dir "$TMP/theme" --output "$THEME_ARCHIVE" >/dev/null
/usr/bin/unzip -Z1 "$THEME_ARCHIVE" | /usr/bin/grep -Fx 'manifest.json' >/dev/null
/usr/bin/unzip -Z1 "$THEME_ARCHIVE" | /usr/bin/grep -Fx 'theme.json' >/dev/null
if /usr/bin/unzip -Z1 "$THEME_ARCHIVE" | /usr/bin/grep -E '\.(js|mjs|css)$' >/dev/null; then
  printf 'Portable theme archive must not contain renderer code.\n' >&2
  exit 1
fi
"$NODE" "$ROOT/scripts/theme-package.mjs" import --archive "$THEME_ARCHIVE" \
  --themes-dir "$TMP/imported/themes" --active-dir "$TMP/imported/theme" >/dev/null
[ -s "$TMP/imported/theme/manifest.json" ]
[ -s "$TMP/imported/theme/theme.json" ]
IMPORTED_ID="$("$NODE" -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).id)' "$TMP/theme/manifest.json")"
[ -s "$TMP/imported/themes/$IMPORTED_ID/theme.json" ]
/bin/mkdir -p "$TMP/rejected-theme"
/bin/cp "$TMP/theme/manifest.json" "$TMP/theme/theme.json" "$TMP/theme/background.png" \
  "$TMP/theme/avatar-user.png" "$TMP/theme/avatar-assistant.png" "$TMP/rejected-theme/"
/usr/bin/printf '%s\n' 'console.log("untrusted renderer code")' > "$TMP/rejected-theme/renderer.js"
(cd "$TMP/rejected-theme" && /usr/bin/zip -q -X -r "$TMP/rejected-theme.zip" .)
if "$NODE" "$ROOT/scripts/theme-package.mjs" validate --archive "$TMP/rejected-theme.zip" >/dev/null 2>&1; then
  printf 'Theme package validation accepted untrusted renderer code.\n' >&2
  exit 1
fi
PAYLOAD_JSON="$("$NODE" "$ROOT/scripts/injector.mjs" --check-payload --theme-dir "$TMP/theme")"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (!value.pass || value.themeName !== "测试主题" || value.backgroundName !== "测试背景" || value.imageBytes < 1) process.exit(1);
  if (value.avatarBytes?.user < 1 || value.avatarBytes?.assistant < 1) process.exit(1);
  if (value.effects?.taskPanelOpacity !== 0.61 || value.effects?.taskPanelBlur !== 19) process.exit(1);
  if (value.headerText?.title !== "测试工作台" || value.headerText?.subtitle !== "TEST STAGE" || value.headerText?.status !== "READY") process.exit(1);
  if (value.layoutId !== "qq-classic" || value.layoutComponents?.companion !== false || value.layoutComponents?.windowTitle !== "测试 Codex 2007") process.exit(1);
  if (value.layoutAssetBytes < 1) process.exit(1);
' "$PAYLOAD_JSON"
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (t.colors.background !== "#081018" || t.colors.panel !== "#102030" || t.colors.panelAlt !== "#183048") process.exit(1);
  if (t.colors.accent !== "#11aa55" || t.colors.accentAlt !== "#44cc77" || t.colors.line !== "rgba(17, 170, 85, 0.4)") process.exit(1);
  if (t.avatars?.user !== "avatar-user.png" || t.avatars?.assistant !== "avatar-assistant.png") process.exit(1);
' "$TMP/theme/theme.json"

if [ "$CODEX_RUNTIME_AVAILABLE" = "true" ]; then
  AVATAR_HOME="$TMP/avatar-home"
  HOME="$AVATAR_HOME" "$ROOT/scripts/customize-theme-macos.sh" \
    --image "$ROOT/themes/builtin-miku-aqua/background.png" --name '头像上传测试' --background-name '测试背景' \
    --user-avatar "$ROOT/themes/builtin-miku-aqua/background.png" --assistant-avatar "$ROOT/themes/builtin-miku-aqua/background.png" \
    --save-theme --no-apply >/dev/null
  AVATAR_STATE="$AVATAR_HOME/Library/Application Support/CodexDreamSkinStudio"
  [ -s "$AVATAR_STATE/theme/avatar-user.jpg" ]
  [ -s "$AVATAR_STATE/theme/avatar-assistant.jpg" ]
  AVATAR_HISTORY="$(/usr/bin/find "$AVATAR_STATE/themes" -mindepth 1 -maxdepth 1 -type d | /usr/bin/head -n 1)"
  [ -n "$AVATAR_HISTORY" ]
  [ -s "$AVATAR_HISTORY/avatar-user.jpg" ]
  [ -s "$AVATAR_HISTORY/avatar-assistant.jpg" ]
  "$NODE" -e '
    const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (t.avatars?.user !== "avatar-user.jpg" || t.avatars?.assistant !== "avatar-assistant.jpg") process.exit(1);
  ' "$AVATAR_STATE/theme/theme.json"
  HOME="$AVATAR_HOME" "$ROOT/scripts/customize-theme-macos.sh" \
    --image "$ROOT/themes/builtin-miku-aqua/background.png" --name '头像移除测试' \
    --clear-user-avatar --clear-assistant-avatar --no-apply >/dev/null
  [ ! -e "$AVATAR_STATE/theme/avatar-user.jpg" ]
  [ ! -e "$AVATAR_STATE/theme/avatar-assistant.jpg" ]
  "$NODE" -e '
    const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (t.avatars?.user !== null || t.avatars?.assistant !== null) process.exit(1);
  ' "$AVATAR_STATE/theme/theme.json"
fi

"$NODE" "$ROOT/scripts/update-theme-preferences.mjs" effects --theme-dir "$TMP/theme" \
  --opacity 43 --blur 21.5 >/dev/null
"$NODE" "$ROOT/scripts/update-theme-preferences.mjs" header --theme-dir "$TMP/theme" \
  --title '我的初音工作台' --subtitle 'MIKU DEV STAGE' --status 'READY TO CODE' >/dev/null

for palette in "$ROOT"/palettes/*.json; do
  "$NODE" -e '
    const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const keys = ["background", "panel", "panelAlt", "accent", "accentAlt", "secondary", "highlight", "text", "muted", "line"];
    const visualStyles = new Set(["miku-07", "classic-blue-07"]);
    const layouts = new Set(["stage", "qq-classic"]);
    if (p.schemaVersion !== 1 || !p.id || !p.name || !layouts.has(p.layoutId) || !visualStyles.has(p.visualStyle) || keys.some((key) => !p.colors?.[key])) process.exit(1);
  ' "$palette"
done

for layout in "$ROOT"/layouts/*.json; do
  "$NODE" -e '
    const value = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (value.schemaVersion !== 1 || !value.id || !value.name || !value.defaultPaletteId || !Array.isArray(value.editableSections)) process.exit(1);
  ' "$layout"
done

LAYOUT_HOME="$TMP/layout-home"
LAYOUT_THEME="$LAYOUT_HOME/Library/Application Support/CodexDreamSkinStudio/theme"
/bin/mkdir -p "$LAYOUT_THEME"
/bin/cp "$ROOT/themes/builtin-miku-aqua/background.png" "$LAYOUT_THEME/background.png"
"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$LAYOUT_THEME" \
  --image background.png --name '布局切换测试' --layout-id stage >/dev/null
HOME="$LAYOUT_HOME" "$ROOT/scripts/switch-layout-macos.sh" --id qq-classic --no-apply >/dev/null 2>&1
"$NODE" -e '
  const value = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (value.layoutId !== "qq-classic" || value.paletteId !== "classic-blue" || value.layoutComponents?.threePane !== true) process.exit(1);
' "$LAYOUT_THEME/theme.json"

/usr/bin/grep -F 'classic-three-pane' "$ROOT/renderer/layouts/qq-classic/qq-classic-renderer.js" >/dev/null
/usr/bin/grep -F '#codex-qq-skin-retro-shell' "$ROOT/renderer/layouts/qq-classic/qq-classic.css" >/dev/null
/usr/bin/grep -F 'layoutComponents' "$ROOT/scripts/injector.mjs" >/dev/null
/usr/bin/grep -F 'if (!watchMode)' "$ROOT/scripts/injector.mjs" >/dev/null
/usr/bin/grep -F 'process.exit(process.exitCode ?? 0)' "$ROOT/scripts/injector.mjs" >/dev/null
/usr/bin/grep -F '取消当前操作' "$ROOT/app/Sources/CodexDreamSkinMenuBar/AppDelegate.swift" >/dev/null
/usr/bin/grep -F 'CODEX_DREAM_SKIN_STORE_URL' "$ROOT/app/Sources/CodexDreamSkinMenuBar/AppDelegate.swift" >/dev/null
/usr/bin/grep -F 'https://skin.beanplay.cn' "$ROOT/app/Sources/CodexDreamSkinMenuBar/AppDelegate.swift" >/dev/null
/usr/bin/grep -F 'openThemeStore' "$ROOT/app/Sources/CodexDreamSkinMenuBar/AppDelegate.swift" >/dev/null
/usr/bin/grep -F 'scriptTimedOut' "$ROOT/app/Sources/CodexDreamSkinMenuBar/EngineController.swift" >/dev/null
/usr/bin/grep -F 'dream-skin-project-button' "$ROOT/renderer/layouts/stage/renderer-inject.js" >/dev/null
/usr/bin/grep -F '.dream-skin-project-button' "$ROOT/renderer/layouts/stage/dream-skin.css" >/dev/null
/usr/bin/grep -F "home?.querySelector('.dream-skin-project-button')" "$ROOT/scripts/injector.mjs" >/dev/null
/usr/bin/grep -F 'data-content-search-unit-key' "$ROOT/renderer/layouts/stage/renderer-inject.js" >/dev/null
/usr/bin/grep -F '.dream-skin-chat-avatar' "$ROOT/renderer/layouts/stage/dream-skin.css" >/dev/null
/usr/bin/grep -F 'tab(title: "对话头像"' \
  "$ROOT/app/Sources/CodexDreamSkinMenuBar/ThemeEditorWindowController.swift" >/dev/null
/usr/bin/grep -F '("qq-classic", "经典蓝 QQ 工作台", "classic-blue-07")' \
  "$ROOT/app/Sources/CodexDreamSkinMenuBar/ThemeEditorWindowController.swift" >/dev/null

"$NODE" "$ROOT/scripts/write-theme.mjs" apply-palette --output-dir "$TMP/theme" \
  --palette "$ROOT/palettes/classic-blue.json" >/dev/null
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (t.image !== "background.png" || t.paletteId !== "classic-blue" || t.visualStyle !== "classic-blue-07" || t.layoutId !== "qq-classic") process.exit(1);
  if (t.colors.accent !== "#2674c7" || t.colors.background !== "#dceefb") process.exit(1);
  if (t.avatars?.user !== "avatar-user.png" || t.avatars?.assistant !== "avatar-assistant.png") process.exit(1);
  if (t.effects?.taskPanelOpacity !== 0.43 || t.effects?.taskPanelBlur !== 21.5) process.exit(1);
  if (t.headerText?.title !== "我的初音工作台" || t.headerText?.subtitle !== "MIKU DEV STAGE" || t.headerText?.status !== "READY TO CODE") process.exit(1);
' "$TMP/theme/theme.json"
CLASSIC_PAYLOAD_JSON="$("$NODE" "$ROOT/scripts/injector.mjs" --check-payload --theme-dir "$TMP/theme")"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (!value.pass || value.paletteId !== "classic-blue" || value.visualStyle !== "classic-blue-07" || value.layoutId !== "qq-classic") process.exit(1);
  if (value.themeName !== "经典蓝默认方案" || value.payloadBytes < 1 || value.layoutAssetBytes < 1) process.exit(1);
' "$CLASSIC_PAYLOAD_JSON"

"$NODE" "$ROOT/scripts/write-theme.mjs" apply-palette --output-dir "$TMP/theme" \
  --palette "$ROOT/palettes/miku-aqua.json" >/dev/null
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (t.image !== "background.png" || t.paletteId !== "miku-aqua" || t.visualStyle !== "miku-07" || t.layoutId !== "stage" || t.colors.accent !== "#39c5bb") process.exit(1);
  if (t.effects?.taskPanelOpacity !== 0.43 || t.effects?.taskPanelBlur !== 21.5) process.exit(1);
  if (t.headerText?.title !== "我的初音工作台" || t.headerText?.subtitle !== "MIKU DEV STAGE" || t.headerText?.status !== "READY TO CODE") process.exit(1);
' "$TMP/theme/theme.json"

/bin/cp "$ROOT/themes/builtin-miku-aqua/background.png" "$TMP/theme/background-next.png"
"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background-next.png --background-name 'Luna' --inherit-theme "$TMP/theme/theme.json" >/dev/null
PAYLOAD_JSON="$("$NODE" "$ROOT/scripts/injector.mjs" --check-payload --theme-dir "$TMP/theme")"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (!value.pass || value.paletteId !== "miku-aqua" || value.visualStyle !== "miku-07" || value.backgroundName !== "Luna") process.exit(1);
  if (value.avatarBytes?.user < 1 || value.avatarBytes?.assistant < 1) process.exit(1);
  if (value.effects?.taskPanelOpacity !== 0.43 || value.effects?.taskPanelBlur !== 21.5) process.exit(1);
  if (value.headerText?.title !== "我的初音工作台" || value.headerText?.subtitle !== "MIKU DEV STAGE" || value.headerText?.status !== "READY TO CODE") process.exit(1);
' "$PAYLOAD_JSON"

"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background-next.png --inherit-theme "$TMP/theme/theme.json" \
  --brand-subtitle '' --tagline '' --project-prefix '' --project-label '' --status-text '' --quote '' \
  --header-title '' --header-subtitle '' --header-status '' \
  --clear-user-avatar --clear-assistant-avatar >/dev/null
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const empty = [t.brandSubtitle, t.tagline, t.projectPrefix, t.projectLabel, t.statusText, t.quote,
    t.headerText?.title, t.headerText?.subtitle, t.headerText?.status];
  if (empty.some((value) => value !== "")) process.exit(1);
  if (t.paletteId !== "miku-aqua" || t.backgroundName !== "Luna") process.exit(1);
  if (t.avatars?.user !== null || t.avatars?.assistant !== null) process.exit(1);
' "$TMP/theme/theme.json"
"$NODE" "$ROOT/scripts/write-theme.mjs" reset-demo --output-dir "$TMP/theme" >/dev/null
[ ! -e "$TMP/theme" ]

CONFIG="$TMP/config.toml"
BACKUP="$TMP/theme-backup.json"
/usr/bin/printf '%s\n' \
  'model = "gpt-5"' \
  '' \
  '[desktop]' \
  'appearanceTheme = "system"' \
  'appearanceDarkCodeThemeId = "vscode-dark"' \
  'keepMe = true' > "$CONFIG"
/bin/cp "$CONFIG" "$TMP/original.toml"
"$NODE" "$ROOT/scripts/theme-config.mjs" install "$CONFIG" "$BACKUP" >/dev/null
/usr/bin/cmp -s "$CONFIG" "$TMP/original.toml"
[ -s "$BACKUP" ]
"$NODE" "$ROOT/scripts/theme-config.mjs" restore "$CONFIG" "$BACKUP" >/dev/null
/usr/bin/cmp -s "$CONFIG" "$TMP/original.toml"

/usr/bin/env -u HOME /bin/bash -c '. "$1/scripts/common-macos.sh"; [ -n "$HOME" ] && [ "$SKIN_VERSION" = "$2" ]' _ "$ROOT" "$VERSION"
STATE_VERSION=""
STATE_PATH="$HOME/Library/Application Support/CodexDreamSkinStudio/state.json"
if [ -f "$STATE_PATH" ]; then
  STATE_VERSION="$($NODE -e '
    try { process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).skinVersion || "") } catch {}
  ' "$STATE_PATH")"
fi
if [ "$CODEX_RUNTIME_AVAILABLE" = "true" ] && [ -f "$HOME/.codex/config.toml" ] && \
   { [ -z "$STATE_VERSION" ] || [ "$STATE_VERSION" = "$VERSION" ]; }; then
  "$ROOT/scripts/doctor-macos.sh" >/dev/null
  DOCTOR_RESULT="doctor"
else
  DOCTOR_RESULT="doctor skipped (runtime/config unavailable or live session uses another version)"
fi

printf 'PASS: syntax, full theme authoring, chat avatars, empty copy, palette/background independence, config round-trip, HOME recovery, and %s checks.\n' "$DOCTOR_RESULT"
