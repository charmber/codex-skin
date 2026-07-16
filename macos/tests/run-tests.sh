#!/bin/bash

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
NODE="${NODE:-/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node}"
[ -x "$NODE" ] || { printf 'Codex bundled Node.js was not found: %s\n' "$NODE" >&2; exit 1; }

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
/bin/mkdir -p "$TMP/theme"
/bin/cp "$ROOT/assets/portal-hero.png" "$TMP/theme/background.png"
"$NODE" "$ROOT/scripts/write-theme.mjs" custom --output-dir "$TMP/theme" \
  --image background.png --name '测试主题' --tagline '测试口号' --quote 'TEST' \
  --accent '#11aa55' --secondary '#22bbcc' --highlight '#663399' >/dev/null
PAYLOAD_JSON="$("$NODE" "$ROOT/scripts/injector.mjs" --check-payload --theme-dir "$TMP/theme")"
"$NODE" -e '
  const value = JSON.parse(process.argv[1]);
  if (!value.pass || value.themeName !== "测试主题" || value.imageBytes < 1) process.exit(1);
' "$PAYLOAD_JSON"

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

/usr/bin/env -u HOME /bin/bash -c '. "$1/scripts/common-macos.sh"; [ -n "$HOME" ] && [ "$SKIN_VERSION" = "1.3.1" ]' _ "$ROOT"
"$ROOT/scripts/doctor-macos.sh" >/dev/null

printf 'PASS: syntax, payload, reading/header preferences, palette/background independence, config round-trip, HOME recovery, signature, and doctor checks.\n'
