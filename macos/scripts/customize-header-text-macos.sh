#!/bin/bash

# Customize the top-left brand copy and top-right status copy.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

TITLE=""
SUBTITLE=""
STATUS_TEXT=""
TITLE_SET="false"
SUBTITLE_SET="false"
STATUS_SET="false"
APPLY_NOW="true"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --title) TITLE="${2-}"; TITLE_SET="true"; shift 2 ;;
    --subtitle) SUBTITLE="${2-}"; SUBTITLE_SET="true"; shift 2 ;;
    --status) STATUS_TEXT="${2-}"; STATUS_SET="true"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    *) fail "Unknown header text argument: $1" ;;
  esac
done

ensure_state_root
ensure_node_runtime
[ -f "$THEME_DIR/theme.json" ] || fail "Choose a theme before customizing header text."

CURRENT_JSON="$("$NODE" "$SCRIPT_DIR/update-theme-preferences.mjs" show --theme-dir "$THEME_DIR")"
CURRENT_TITLE="$("$NODE" -e 'const v=JSON.parse(process.argv[1]);process.stdout.write(v.headerText.title)' "$CURRENT_JSON")"
CURRENT_SUBTITLE="$("$NODE" -e 'const v=JSON.parse(process.argv[1]);process.stdout.write(v.headerText.subtitle)' "$CURRENT_JSON")"
CURRENT_STATUS="$("$NODE" -e 'const v=JSON.parse(process.argv[1]);process.stdout.write(v.headerText.status)' "$CURRENT_JSON")"

prompt_text() {
  local prompt="$1"
  local default_value="$2"
  DREAM_SKIN_PROMPT="$prompt" DREAM_SKIN_DEFAULT="$default_value" /usr/bin/osascript <<'APPLESCRIPT'
set promptText to system attribute "DREAM_SKIN_PROMPT"
set defaultValue to system attribute "DREAM_SKIN_DEFAULT"
text returned of (display dialog promptText default answer defaultValue buttons {"取消", "继续"} default button "继续" with title "Codex Dream Skin")
APPLESCRIPT
}

if [ "$TITLE_SET" != "true" ] && [ "$SUBTITLE_SET" != "true" ] && [ "$STATUS_SET" != "true" ]; then
  TITLE="$(prompt_text "左上角标题（留空可隐藏）" "$CURRENT_TITLE")" || fail "Header setup was cancelled."
  SUBTITLE="$(prompt_text "左上角副标题（留空可隐藏）" "$CURRENT_SUBTITLE")" || fail "Header setup was cancelled."
  STATUS_TEXT="$(prompt_text "右上角状态文字（留空可隐藏）" "$CURRENT_STATUS")" || fail "Header setup was cancelled."
  TITLE_SET="true"
  SUBTITLE_SET="true"
  STATUS_SET="true"
fi

update_args=(header --theme-dir "$THEME_DIR")
[ "$TITLE_SET" = "true" ] && update_args+=(--title "$TITLE")
[ "$SUBTITLE_SET" = "true" ] && update_args+=(--subtitle "$SUBTITLE")
[ "$STATUS_SET" = "true" ] && update_args+=(--status "$STATUS_TEXT")
"$NODE" "$SCRIPT_DIR/update-theme-preferences.mjs" "${update_args[@]}" >/dev/null

progress() {
  printf '%s\n' "$*" >&2
  /usr/bin/osascript -e "display notification \"$*\" with title \"Codex Dream Skin\"" >/dev/null 2>&1 || true
}

if [ "$APPLY_NOW" != "true" ]; then
  progress "顶部文字已保存"
  exit 0
fi

PORT=9341
if [ -f "$STATE_PATH" ]; then
  saved="$(state_field port 2>/dev/null || true)"
  [ -n "${saved:-}" ] && PORT="$saved"
fi

progress "正在应用顶部文字…"
if hot_reapply_theme "$PORT" 8000; then
  progress "顶部文字已应用"
  exit 0
fi

if "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing; then
  progress "顶部文字已应用"
  exit 0
fi

fail "Header text was saved but could not be applied."
