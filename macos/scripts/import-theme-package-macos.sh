#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

ARCHIVE=""
APPLY_NOW="true"
LIBRARY_ONLY="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --file) ARCHIVE="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    --library-only) LIBRARY_ONLY="true"; APPLY_NOW="false"; shift ;;
    *) fail "Unknown import argument: $1" ;;
  esac
done

if [ -z "$ARCHIVE" ]; then
  ARCHIVE="$(/usr/bin/osascript -e 'POSIX path of (choose file with prompt "选择 Codex Dream Skin 主题包" of type {"public.zip-archive"})')" \
    || fail "Theme package selection was cancelled."
fi
[ -f "$ARCHIVE" ] || fail "Theme package does not exist: $ARCHIVE"

ensure_state_root
ensure_node_runtime
/bin/mkdir -p "$STATE_ROOT/themes"
arguments=(import --archive "$ARCHIVE" --themes-dir "$STATE_ROOT/themes" --active-dir "$THEME_DIR")
[ "$LIBRARY_ONLY" = "true" ] && arguments+=(--library-only)
RESULT="$("$NODE" "$SCRIPT_DIR/theme-package.mjs" "${arguments[@]}")"
THEME_NAME="$("$NODE" -e 'const value=JSON.parse(process.argv[1]);process.stdout.write(value.name||value.id||"主题")' "$RESULT")"

if [ "$LIBRARY_ONLY" = "true" ]; then
  printf 'Imported theme package to library: %s\n' "$THEME_NAME"
  exit 0
fi
if [ "$APPLY_NOW" != "true" ]; then
  printf 'Imported and activated theme package without applying: %s\n' "$THEME_NAME"
  exit 0
fi

PORT=9341
if [ -f "$STATE_PATH" ]; then
  saved="$(state_field port 2>/dev/null || true)"
  [ -n "${saved:-}" ] && PORT="$saved"
fi
if ! hot_reapply_theme "$PORT" 8000; then
  "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --prompt-restart
fi
printf 'Imported and applied theme package: %s\n' "$THEME_NAME"
