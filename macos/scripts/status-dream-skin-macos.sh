#!/bin/bash

# Fast status for SwiftBar. No codesign / CDP probes by default.

set +e
set -u

SHORT="false"
JSON="false"
DEEP="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --short) SHORT="true"; shift ;;
    --json) JSON="true"; shift ;;
    --deep) DEEP="true"; shift ;;
    *) printf 'Unknown status argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

STATE_ROOT="${HOME}/Library/Application Support/CodexDreamSkinStudio"
STATE_PATH="${STATE_ROOT}/state.json"
THEME_DIR="${STATE_ROOT}/theme"

PORT="9341"
SESSION="off"
INJECTOR_ALIVE="false"
CDP_OK="false"
THEME_NAME=""
PALETTE_ID=""
PALETTE_NAME=""
BACKGROUND_NAME=""
PANEL_OPACITY="0.76"
PANEL_BLUR="14"
CODEX_RUNNING="false"

read_json_field() {
  /usr/bin/python3 - "$1" "$2" 2>/dev/null <<'PY' || true
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    v = data
    for part in sys.argv[2].split("."):
        if not isinstance(v, dict) or part not in v:
            v = None
            break
        v = v[part]
    if v is not None:
        print(v, end="")
except Exception:
    pass
PY
}

# Codex process: the executable path is reliable even when pgrep cannot see the
# app's short process name on newer macOS releases.
if /bin/ps -axo command= | /usr/bin/awk '
  /\/ChatGPT\.app\/Contents\/MacOS\/ChatGPT([[:space:]]|$)/ { found = 1 }
  END { exit !found }
'; then
  CODEX_RUNNING="true"
fi

if [ -f "$STATE_PATH" ]; then
  saved_port="$(read_json_field "$STATE_PATH" port)"
  [ -n "${saved_port:-}" ] && PORT="$saved_port"
  SESSION="$(read_json_field "$STATE_PATH" session)"
  pid="$(read_json_field "$STATE_PATH" injectorPid)"
  if [ -n "${pid:-}" ] && [ "$pid" != "0" ] && /bin/kill -0 "$pid" 2>/dev/null; then
    INJECTOR_ALIVE="true"
    SESSION="active"
  elif [ "${SESSION:-}" = "paused" ]; then
    SESSION="paused"
  elif [ -n "${pid:-}" ] && [ "$pid" != "0" ]; then
    SESSION="stale"
  elif [ -z "${SESSION:-}" ]; then
    SESSION="unknown"
  fi
fi

if [ -f "$THEME_DIR/theme.json" ]; then
  THEME_NAME="$(read_json_field "$THEME_DIR/theme.json" name)"
  [ -n "$THEME_NAME" ] || THEME_NAME="$(read_json_field "$THEME_DIR/theme.json" id)"
  PALETTE_ID="$(read_json_field "$THEME_DIR/theme.json" paletteId)"
  PALETTE_NAME="$(read_json_field "$THEME_DIR/theme.json" paletteName)"
  BACKGROUND_NAME="$(read_json_field "$THEME_DIR/theme.json" backgroundName)"
  [ -n "$PALETTE_NAME" ] || PALETTE_NAME="$THEME_NAME"
  [ -n "$BACKGROUND_NAME" ] || BACKGROUND_NAME="$(read_json_field "$THEME_DIR/theme.json" image)"
  saved_opacity="$(read_json_field "$THEME_DIR/theme.json" effects.taskPanelOpacity)"
  saved_blur="$(read_json_field "$THEME_DIR/theme.json" effects.taskPanelBlur)"
  [ -n "$saved_opacity" ] && PANEL_OPACITY="$saved_opacity"
  [ -n "$saved_blur" ] && PANEL_BLUR="$saved_blur"
fi

PANEL_PERCENT="$(/usr/bin/python3 - "$PANEL_OPACITY" <<'PY' 2>/dev/null || printf '76'
import sys
try:
    print(round(float(sys.argv[1]) * 100), end="")
except Exception:
    print("76", end="")
PY
)"

if [ "$DEEP" = "true" ]; then
  if /usr/bin/curl --noproxy '*' --silent --fail --max-time 1 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
    CDP_OK="true"
  fi
fi

label="Skin"
case "$SESSION" in
  active) label="Skin ON" ;;
  paused) label="Skin 暂停" ;;
  stale|unknown) label="Skin ?" ;;
  *) label="Skin 关" ;;
esac

if [ "$SHORT" = "true" ]; then
  printf '%s\n' "$label"
  exit 0
fi

if [ "$JSON" = "true" ]; then
  /usr/bin/python3 - "$SESSION" "$PORT" "$INJECTOR_ALIVE" "$CDP_OK" "$CODEX_RUNNING" "$THEME_NAME" "$PALETTE_ID" "$PALETTE_NAME" "$BACKGROUND_NAME" "$PANEL_PERCENT" "$PANEL_BLUR" <<'PY'
import json, sys
print(json.dumps({
    "session": sys.argv[1],
    "port": int(sys.argv[2]) if str(sys.argv[2]).isdigit() else sys.argv[2],
    "injectorAlive": sys.argv[3] == "true",
    "cdpOk": sys.argv[4] == "true",
    "codexRunning": sys.argv[5] == "true",
    "themeName": sys.argv[6] or "",
    "paletteId": sys.argv[7] or "",
    "paletteName": sys.argv[8] or "",
    "backgroundName": sys.argv[9] or "",
    "taskPanelOpacityPercent": float(sys.argv[10]) if sys.argv[10] else 76,
    "taskPanelBlur": float(sys.argv[11]) if sys.argv[11] else 14,
}))
PY
  exit 0
fi

printf 'session=%s\n' "$SESSION"
printf 'port=%s\n' "$PORT"
printf 'injector=%s\n' "$INJECTOR_ALIVE"
printf 'cdp=%s\n' "$CDP_OK"
printf 'codex=%s\n' "$CODEX_RUNNING"
printf 'theme=%s\n' "${THEME_NAME:-}"
printf 'palette_id=%s\n' "${PALETTE_ID:-}"
printf 'palette=%s\n' "${PALETTE_NAME:-}"
printf 'background=%s\n' "${BACKGROUND_NAME:-}"
printf 'panel_opacity=%s\n' "${PANEL_PERCENT:-76}"
printf 'panel_blur=%s\n' "${PANEL_BLUR:-14}"
