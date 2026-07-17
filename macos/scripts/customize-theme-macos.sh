#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

IMAGE=""
THEME_NAME=""
BACKGROUND_NAME=""
VISUAL_STYLE=""
BRAND_SUBTITLE=""
TAGLINE=""
PROJECT_PREFIX=""
PROJECT_LABEL=""
STATUS_TEXT=""
QUOTE=""
BACKGROUND_COLOR=""
PANEL_COLOR=""
PANEL_ALT_COLOR=""
ACCENT=""
ACCENT_ALT=""
SECONDARY=""
HIGHLIGHT=""
TEXT_COLOR=""
MUTED_COLOR=""
LINE_COLOR=""
TASK_PANEL_OPACITY=""
TASK_PANEL_BLUR=""
HEADER_TITLE=""
HEADER_SUBTITLE=""
HEADER_STATUS=""
APPLY_NOW="true"
RESET_DEMO="false"
SAVE_THEME="false"
HAS_BRAND_SUBTITLE="false"
HAS_TAGLINE="false"
HAS_PROJECT_PREFIX="false"
HAS_PROJECT_LABEL="false"
HAS_STATUS_TEXT="false"
HAS_QUOTE="false"
HAS_HEADER_TITLE="false"
HAS_HEADER_SUBTITLE="false"
HAS_HEADER_STATUS="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image) IMAGE="${2:-}"; shift 2 ;;
    --name) THEME_NAME="${2:-}"; shift 2 ;;
    --background-name) BACKGROUND_NAME="${2:-}"; shift 2 ;;
    --visual-style) VISUAL_STYLE="${2:-}"; shift 2 ;;
    --brand-subtitle) BRAND_SUBTITLE="${2:-}"; HAS_BRAND_SUBTITLE="true"; shift 2 ;;
    --tagline) TAGLINE="${2:-}"; HAS_TAGLINE="true"; shift 2 ;;
    --project-prefix) PROJECT_PREFIX="${2:-}"; HAS_PROJECT_PREFIX="true"; shift 2 ;;
    --project-label) PROJECT_LABEL="${2:-}"; HAS_PROJECT_LABEL="true"; shift 2 ;;
    --status-text) STATUS_TEXT="${2:-}"; HAS_STATUS_TEXT="true"; shift 2 ;;
    --quote) QUOTE="${2:-}"; HAS_QUOTE="true"; shift 2 ;;
    --background-color) BACKGROUND_COLOR="${2:-}"; shift 2 ;;
    --panel-color) PANEL_COLOR="${2:-}"; shift 2 ;;
    --panel-alt-color) PANEL_ALT_COLOR="${2:-}"; shift 2 ;;
    --accent) ACCENT="${2:-}"; shift 2 ;;
    --accent-alt) ACCENT_ALT="${2:-}"; shift 2 ;;
    --secondary) SECONDARY="${2:-}"; shift 2 ;;
    --highlight) HIGHLIGHT="${2:-}"; shift 2 ;;
    --text-color) TEXT_COLOR="${2:-}"; shift 2 ;;
    --muted-color) MUTED_COLOR="${2:-}"; shift 2 ;;
    --line-color) LINE_COLOR="${2:-}"; shift 2 ;;
    --task-panel-opacity) TASK_PANEL_OPACITY="${2:-}"; shift 2 ;;
    --task-panel-blur) TASK_PANEL_BLUR="${2:-}"; shift 2 ;;
    --header-title) HEADER_TITLE="${2:-}"; HAS_HEADER_TITLE="true"; shift 2 ;;
    --header-subtitle) HEADER_SUBTITLE="${2:-}"; HAS_HEADER_SUBTITLE="true"; shift 2 ;;
    --header-status) HEADER_STATUS="${2:-}"; HAS_HEADER_STATUS="true"; shift 2 ;;
    --save-theme) SAVE_THEME="true"; shift ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    --reset-demo) RESET_DEMO="true"; shift ;;
    *) fail "Unknown customize argument: $1" ;;
  esac
done

discover_codex_app
require_macos_runtime
ensure_state_root

if [ "$RESET_DEMO" = "true" ]; then
  "$NODE" "$SCRIPT_DIR/write-theme.mjs" reset-demo --output-dir "$THEME_DIR"
else
  if [ -z "$IMAGE" ]; then
    IMAGE="$(/usr/bin/osascript -e 'POSIX path of (choose file with prompt "选择一张主题图片（建议横向、宽度 2000px 以上）" of type {"public.image"})')" \
      || fail "Image selection was cancelled."
  fi
  [ -f "$IMAGE" ] || fail "Selected image does not exist: $IMAGE"
  SOURCE_BYTES="$(/usr/bin/stat -f '%z' "$IMAGE")"
  [ "$SOURCE_BYTES" -le 52428800 ] || fail "Selected image is larger than 50 MB. Choose a smaller file."

  if [ -z "$THEME_NAME" ]; then
    THEME_NAME="$(/usr/bin/osascript -e 'text returned of (display dialog "给这个主题起个名字" default answer "我的主题" buttons {"取消", "继续"} default button "继续")')" \
      || fail "Theme setup was cancelled."
  fi
  [ -n "$BACKGROUND_NAME" ] || BACKGROUND_NAME="$THEME_NAME"

  /bin/mkdir -p "$THEME_DIR"
  /bin/chmod 700 "$THEME_DIR"
  image_name="background-$(/bin/date '+%Y%m%d-%H%M%S')-$$.jpg"
  temporary="$THEME_DIR/.${image_name}.tmp.jpg"
  prepared="$THEME_DIR/$image_name"
  cleanup_temporary() { /bin/rm -f "$temporary"; }
  trap cleanup_temporary EXIT
  /usr/bin/sips -s format jpeg -s formatOptions 84 -Z 3200 "$IMAGE" --out "$temporary" >/dev/null \
    || fail "macOS could not convert the selected image. Use PNG, JPEG, HEIC, TIFF, or WebP."
  [ -s "$temporary" ] || fail "The converted image is empty."
  PREPARED_BYTES="$(/usr/bin/stat -f '%z' "$temporary")"
  [ "$PREPARED_BYTES" -le 16777216 ] || fail "The prepared image is larger than 16 MB. Choose a simpler or smaller image."
  /bin/mv -f "$temporary" "$prepared"
  /bin/chmod 600 "$prepared"

  theme_args=(custom --output-dir "$THEME_DIR" --image "$image_name" --name "$THEME_NAME" \
    --palette-name "$THEME_NAME" --palette-id custom --background-name "$BACKGROUND_NAME")
  if [ -f "$THEME_DIR/theme.json" ]; then theme_args+=(--inherit-theme "$THEME_DIR/theme.json"); fi
  [ -n "$VISUAL_STYLE" ] && theme_args+=(--visual-style "$VISUAL_STYLE")
  [ "$HAS_BRAND_SUBTITLE" = "true" ] && theme_args+=(--brand-subtitle "$BRAND_SUBTITLE")
  [ "$HAS_TAGLINE" = "true" ] && theme_args+=(--tagline "$TAGLINE")
  [ "$HAS_PROJECT_PREFIX" = "true" ] && theme_args+=(--project-prefix "$PROJECT_PREFIX")
  [ "$HAS_PROJECT_LABEL" = "true" ] && theme_args+=(--project-label "$PROJECT_LABEL")
  [ "$HAS_STATUS_TEXT" = "true" ] && theme_args+=(--status-text "$STATUS_TEXT")
  [ "$HAS_QUOTE" = "true" ] && theme_args+=(--quote "$QUOTE")
  [ -n "$BACKGROUND_COLOR" ] && theme_args+=(--background "$BACKGROUND_COLOR")
  [ -n "$PANEL_COLOR" ] && theme_args+=(--panel "$PANEL_COLOR")
  [ -n "$PANEL_ALT_COLOR" ] && theme_args+=(--panel-alt "$PANEL_ALT_COLOR")
  [ -n "$ACCENT" ] && theme_args+=(--accent "$ACCENT")
  [ -n "$ACCENT_ALT" ] && theme_args+=(--accent-alt "$ACCENT_ALT")
  [ -n "$SECONDARY" ] && theme_args+=(--secondary "$SECONDARY")
  [ -n "$HIGHLIGHT" ] && theme_args+=(--highlight "$HIGHLIGHT")
  [ -n "$TEXT_COLOR" ] && theme_args+=(--text "$TEXT_COLOR")
  [ -n "$MUTED_COLOR" ] && theme_args+=(--muted "$MUTED_COLOR")
  [ -n "$LINE_COLOR" ] && theme_args+=(--line "$LINE_COLOR")
  [ -n "$TASK_PANEL_OPACITY" ] && theme_args+=(--task-panel-opacity "$TASK_PANEL_OPACITY")
  [ -n "$TASK_PANEL_BLUR" ] && theme_args+=(--task-panel-blur "$TASK_PANEL_BLUR")
  [ "$HAS_HEADER_TITLE" = "true" ] && theme_args+=(--header-title "$HEADER_TITLE")
  [ "$HAS_HEADER_SUBTITLE" = "true" ] && theme_args+=(--header-subtitle "$HEADER_SUBTITLE")
  [ "$HAS_HEADER_STATUS" = "true" ] && theme_args+=(--header-status "$HEADER_STATUS")
  "$NODE" "$SCRIPT_DIR/write-theme.mjs" "${theme_args[@]}"

  if [ "$SAVE_THEME" = "true" ]; then
    THEMES_ROOT="$STATE_ROOT/themes"
    IMAGES_ROOT="$STATE_ROOT/images"
    theme_id="user-$(/bin/date '+%Y%m%d%H%M%S')-$$"
    library_dir="$THEMES_ROOT/$theme_id"
    /bin/mkdir -p "$library_dir" "$IMAGES_ROOT"
    /bin/cp -f "$THEME_DIR/$image_name" "$THEME_DIR/theme.json" "$library_dir/"
    /bin/chmod 600 "$library_dir/"*

    source_base="$(/usr/bin/basename "$IMAGE")"
    library_image="$IMAGES_ROOT/${theme_id}-${source_base}"
    /bin/cp -f "$IMAGE" "$library_image" 2>/dev/null || true
    /bin/chmod 600 "$library_image" 2>/dev/null || true
    printf 'Saved theme library entry: %s\n' "$theme_id"
  fi

  /usr/bin/find "$THEME_DIR" -maxdepth 1 -type f -name 'background-*' ! -name "$image_name" -delete
  trap - EXIT
fi

if [ "$APPLY_NOW" = "true" ]; then
  PORT=9341
  if [ -f "$STATE_PATH" ]; then
    saved="$(state_field port 2>/dev/null || true)"
    [ -n "${saved:-}" ] && PORT="$saved"
  fi
  if ! hot_reapply_theme "$PORT" 8000; then
    "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --prompt-restart
  fi
fi

printf 'Codex Dream Skin Studio theme is ready.\n'
