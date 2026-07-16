#!/bin/bash

# Configure the task reading surface without changing palette or background.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

OPACITY=""
BLUR=""
APPLY_NOW="true"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --opacity) OPACITY="${2:-}"; shift 2 ;;
    --blur) BLUR="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    *) fail "Unknown reading panel argument: $1" ;;
  esac
done

ensure_state_root
ensure_node_runtime
[ -f "$THEME_DIR/theme.json" ] || fail "Choose a theme before adjusting the reading panel."

CURRENT_JSON="$("$NODE" "$SCRIPT_DIR/update-theme-preferences.mjs" show --theme-dir "$THEME_DIR")"
CURRENT_OPACITY="$("$NODE" -e 'const v=JSON.parse(process.argv[1]);process.stdout.write(String(Math.round(v.effects.taskPanelOpacity*100)))' "$CURRENT_JSON")"
CURRENT_BLUR="$("$NODE" -e 'const v=JSON.parse(process.argv[1]);process.stdout.write(String(v.effects.taskPanelBlur))' "$CURRENT_JSON")"

if [ -z "$OPACITY" ] && [ -z "$BLUR" ]; then
  DIALOG_RESULT="$(/usr/bin/osascript -l JavaScript "$SCRIPT_DIR/reading-panel-dialog-macos.js" \
    "$CURRENT_OPACITY" "$CURRENT_BLUR" 2>/dev/null)" \
    || fail "Reading panel setup was cancelled."
  IFS=$'\t' read -r OPACITY BLUR <<<"$DIALOG_RESULT"
else
  [ -n "$OPACITY" ] || OPACITY="$CURRENT_OPACITY"
  [ -n "$BLUR" ] || BLUR="$CURRENT_BLUR"
fi

"$NODE" "$SCRIPT_DIR/update-theme-preferences.mjs" effects --theme-dir "$THEME_DIR" \
  --opacity "$OPACITY" --blur "$BLUR" >/dev/null

progress() {
  printf '%s\n' "$*" >&2
  /usr/bin/osascript -e "display notification \"$*\" with title \"Codex Dream Skin\"" >/dev/null 2>&1 || true
}

if [ "$APPLY_NOW" != "true" ]; then
  progress "阅读区效果已保存：${OPACITY}% / ${BLUR}px"
  exit 0
fi

PORT=9341
if [ -f "$STATE_PATH" ]; then
  saved="$(state_field port 2>/dev/null || true)"
  [ -n "${saved:-}" ] && PORT="$saved"
fi

progress "正在应用阅读区效果…"
if hot_reapply_theme "$PORT" 8000; then
  progress "已应用：${OPACITY}% / ${BLUR}px"
  exit 0
fi

if "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing; then
  progress "已应用：${OPACITY}% / ${BLUR}px"
  exit 0
fi

fail "Reading panel settings were saved but could not be applied."
