#!/bin/bash

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CODEX_NODE="/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node"
CODEX_RUNTIME_AVAILABLE="false"
if [ -x "$CODEX_NODE" ]; then CODEX_RUNTIME_AVAILABLE="true"; fi
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
  /usr/bin/find "$ROOT/scripts" "$ROOT/assets" -type f \( -name '*.mjs' -o -name '*.js' \) -print
)

if /usr/bin/grep -R -n -E 'dream-skin-skin|DREAM_SKIN_SKIN|1\.0\.0-rc2' \
  "$ROOT/scripts" "$ROOT/assets" >/dev/null; then
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
/usr/bin/grep -F '调整阅读区磨砂与透明度… | bash=' <<<"$MENU_OUTPUT" >/dev/null
/usr/bin/grep -F '自定义顶部文字… | bash=' <<<"$MENU_OUTPUT" >/dev/null
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
/bin/cp "$ROOT/assets/portal-hero.png" "$TMP/theme/background.png"
"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background.png --name '测试主题' --background-name '测试背景' --visual-style portal \
  --brand-subtitle 'TEST CODEX' --tagline '测试口号' --project-prefix '项目 · ' \
  --project-label '选择测试项目' --status-text 'TEST ONLINE' --quote 'TEST' \
  --background '#081018' --panel '#102030' --panel-alt '#183048' \
  --accent '#11aa55' --accent-alt '#44cc77' --secondary '#22bbcc' --highlight '#663399' \
  --text '#f5fff8' --muted '#99bbaa' --line 'rgba(17, 170, 85, 0.4)' \
  --task-panel-opacity 61 --task-panel-blur 19 \
  --header-title '测试工作台' --header-subtitle 'TEST STAGE' --header-status 'READY' >/dev/null
PAYLOAD_JSON="$("$NODE" "$ROOT/scripts/injector.mjs" --check-payload --theme-dir "$TMP/theme")"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (!value.pass || value.themeName !== "测试主题" || value.backgroundName !== "测试背景" || value.imageBytes < 1) process.exit(1);
  if (value.effects?.taskPanelOpacity !== 0.61 || value.effects?.taskPanelBlur !== 19) process.exit(1);
  if (value.headerText?.title !== "测试工作台" || value.headerText?.subtitle !== "TEST STAGE" || value.headerText?.status !== "READY") process.exit(1);
' "$PAYLOAD_JSON"
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (t.colors.background !== "#081018" || t.colors.panel !== "#102030" || t.colors.panelAlt !== "#183048") process.exit(1);
  if (t.colors.accent !== "#11aa55" || t.colors.accentAlt !== "#44cc77" || t.colors.line !== "rgba(17, 170, 85, 0.4)") process.exit(1);
' "$TMP/theme/theme.json"

"$NODE" "$ROOT/scripts/update-theme-preferences.mjs" effects --theme-dir "$TMP/theme" \
  --opacity 43 --blur 21.5 >/dev/null
"$NODE" "$ROOT/scripts/update-theme-preferences.mjs" header --theme-dir "$TMP/theme" \
  --title '我的初音工作台' --subtitle 'MIKU DEV STAGE' --status 'READY TO CODE' >/dev/null

for palette in "$ROOT"/palettes/*.json; do
  "$NODE" -e '
    const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const keys = ["background", "panel", "panelAlt", "accent", "accentAlt", "secondary", "highlight", "text", "muted", "line"];
    if (p.schemaVersion !== 1 || !p.id || !p.name || p.visualStyle !== "miku-07" || keys.some((key) => !p.colors?.[key])) process.exit(1);
  ' "$palette"
done

"$NODE" "$ROOT/scripts/write-theme.mjs" apply-palette --output-dir "$TMP/theme" \
  --palette "$ROOT/palettes/miku-aqua.json" >/dev/null
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (t.image !== "background.png" || t.paletteId !== "miku-aqua" || t.visualStyle !== "miku-07" || t.colors.accent !== "#39c5bb") process.exit(1);
  if (t.effects?.taskPanelOpacity !== 0.43 || t.effects?.taskPanelBlur !== 21.5) process.exit(1);
  if (t.headerText?.title !== "我的初音工作台" || t.headerText?.subtitle !== "MIKU DEV STAGE" || t.headerText?.status !== "READY TO CODE") process.exit(1);
' "$TMP/theme/theme.json"

/bin/cp "$ROOT/assets/portal-hero.png" "$TMP/theme/background-next.png"
"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background-next.png --background-name 'Luna' --inherit-theme "$TMP/theme/theme.json" >/dev/null
PAYLOAD_JSON="$("$NODE" "$ROOT/scripts/injector.mjs" --check-payload --theme-dir "$TMP/theme")"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (!value.pass || value.paletteId !== "miku-aqua" || value.visualStyle !== "miku-07" || value.backgroundName !== "Luna") process.exit(1);
  if (value.effects?.taskPanelOpacity !== 0.43 || value.effects?.taskPanelBlur !== 21.5) process.exit(1);
  if (value.headerText?.title !== "我的初音工作台" || value.headerText?.subtitle !== "MIKU DEV STAGE" || value.headerText?.status !== "READY TO CODE") process.exit(1);
' "$PAYLOAD_JSON"

"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background-next.png --inherit-theme "$TMP/theme/theme.json" \
  --brand-subtitle '' --tagline '' --project-prefix '' --project-label '' --status-text '' --quote '' \
  --header-title '' --header-subtitle '' --header-status '' >/dev/null
"$NODE" -e '
  const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const empty = [t.brandSubtitle, t.tagline, t.projectPrefix, t.projectLabel, t.statusText, t.quote,
    t.headerText?.title, t.headerText?.subtitle, t.headerText?.status];
  if (empty.some((value) => value !== "")) process.exit(1);
  if (t.paletteId !== "miku-aqua" || t.backgroundName !== "Luna") process.exit(1);
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

printf 'PASS: syntax, full theme authoring, empty copy, palette/background independence, config round-trip, HOME recovery, and %s checks.\n' "$DOCTOR_RESULT"
