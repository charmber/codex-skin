#!/bin/bash

# Switch UI colors while preserving the active background image.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

PALETTE_ID=""
APPLY_NOW="true"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --id) PALETTE_ID="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[ -n "$PALETTE_ID" ] || fail "Usage: switch-palette-macos.sh --id <palette-id>"
case "$PALETTE_ID" in *[!A-Za-z0-9_-]*) fail "Invalid palette id: $PALETTE_ID" ;; esac

PALETTE="$PROJECT_ROOT/palettes/$PALETTE_ID.json"
[ -f "$PALETTE" ] || fail "Palette not found: $PALETTE_ID"
[ -f "$THEME_DIR/theme.json" ] || fail "Choose a background before switching palettes."

ensure_node_runtime
"$NODE" "$SCRIPT_DIR/write-theme.mjs" apply-palette \
  --output-dir "$THEME_DIR" --palette "$PALETTE" >/dev/null

PALETTE_NAME="$("$NODE" -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(p.name||p.id||"")' "$PALETTE")"

progress() {
  printf '%s\n' "$*" >&2
  /usr/bin/osascript -e "display notification \"$*\" with title \"Codex Dream Skin\"" >/dev/null 2>&1 || true
}

if [ "$APPLY_NOW" != "true" ]; then
  progress "Ready: ${PALETTE_NAME} (not applied)"
  exit 0
fi

PORT=9341
if [ -f "$STATE_PATH" ]; then
  saved="$(state_field port 2>/dev/null || true)"
  [ -n "${saved:-}" ] && PORT="$saved"
fi

progress "Applying palette: ${PALETTE_NAME}"
if hot_reapply_theme "$PORT" 8000; then
  progress "Done: ${PALETTE_NAME}"
  exit 0
fi

progress "CDP not ready, full start..."
if "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing; then
  progress "Done: ${PALETTE_NAME}"
  exit 0
fi

/usr/bin/osascript -e 'display alert "Codex Dream Skin" message "Palette saved but inject failed. Click Apply Skin."' >/dev/null 2>&1 || true
exit 1
