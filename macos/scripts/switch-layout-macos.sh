#!/bin/bash

# Switch the structural renderer and apply its default compatible palette.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

LAYOUT_ID=""
APPLY_NOW="true"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --id) LAYOUT_ID="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[ -n "$LAYOUT_ID" ] || fail "Usage: switch-layout-macos.sh --id <layout-id>"
case "$LAYOUT_ID" in *[!A-Za-z0-9_-]*) fail "Invalid layout id: $LAYOUT_ID" ;; esac

MANIFEST="$PROJECT_ROOT/layouts/$LAYOUT_ID.json"
[ -f "$MANIFEST" ] || fail "Layout not found: $LAYOUT_ID"
ensure_node_runtime
DEFAULT_PALETTE="$($NODE -e '
  const value = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (value.schemaVersion !== 1 || value.id !== process.argv[2] || !value.defaultPaletteId) process.exit(1);
  process.stdout.write(value.defaultPaletteId);
' "$MANIFEST" "$LAYOUT_ID")" || fail "Invalid layout manifest: $LAYOUT_ID"

arguments=(--id "$DEFAULT_PALETTE")
[ "$APPLY_NOW" = "true" ] || arguments+=(--no-apply)
exec "$SCRIPT_DIR/switch-palette-macos.sh" "${arguments[@]}"
