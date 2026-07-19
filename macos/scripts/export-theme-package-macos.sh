#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

OUTPUT=""
SOURCE_DIR="$THEME_DIR"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --source-dir) SOURCE_DIR="${2:-}"; shift 2 ;;
    *) fail "Unknown export argument: $1" ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  OUTPUT="$(/usr/bin/osascript -e 'POSIX path of (choose file name with prompt "导出当前 Codex Dream Skin 主题" default name "Codex-Dream-Skin-Theme.cds-theme.zip")')" \
    || fail "Theme package export was cancelled."
fi
case "$OUTPUT" in *.zip) ;; *) OUTPUT="$OUTPUT.zip" ;; esac

ensure_state_root
ensure_node_runtime
RESULT="$("$NODE" "$SCRIPT_DIR/theme-package.mjs" export --source-dir "$SOURCE_DIR" --output "$OUTPUT")"
THEME_NAME="$("$NODE" -e 'const value=JSON.parse(process.argv[1]);process.stdout.write(value.name||value.id||"主题")' "$RESULT")"
printf 'Exported theme package: %s\nPath: %s\n' "$THEME_NAME" "$OUTPUT"
