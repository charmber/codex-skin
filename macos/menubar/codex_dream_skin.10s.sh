#!/bin/bash

# SwiftBar plugin — dynamic theme list from themes/ + images/ drop folder.

# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>false</swiftbar.hideSwiftBar>

set +e

ENGINE="${CODEX_DREAM_SKIN_ENGINE:-$HOME/.codex/codex-dream-skin-studio}"
THEME_STORE_URL="${CODEX_DREAM_SKIN_STORE_URL:-http://skin.beadplay.cn}"
case "$THEME_STORE_URL" in
  http://*|https://*) ;;
  *) THEME_STORE_URL="http://skin.beadplay.cn" ;;
esac
if [ ! -d "$ENGINE/scripts" ]; then
  HERE="$(cd "$(dirname "$0")" && pwd -P)"
  [ -d "$HERE/../scripts" ] && ENGINE="$(cd "$HERE/.." && pwd -P)"
fi

SCRIPTS="$ENGINE/scripts"
APPLY="$SCRIPTS/apply-from-menubar-macos.sh"
START="$SCRIPTS/start-dream-skin-macos.sh"
PAUSE="$SCRIPTS/pause-dream-skin-macos.sh"
CUSTOMIZE="$SCRIPTS/customize-theme-macos.sh"
RESTORE="$SCRIPTS/restore-dream-skin-macos.sh"
STATUS="$SCRIPTS/status-dream-skin-macos.sh"
SWITCH="$SCRIPTS/switch-theme-macos.sh"
SWITCH_PALETTE="$SCRIPTS/switch-palette-macos.sh"
SWITCH_LAYOUT="$SCRIPTS/switch-layout-macos.sh"
LOAD_IMG="$SCRIPTS/load-image-theme-macos.sh"
READING_PANEL="$SCRIPTS/configure-reading-panel-macos.sh"
HEADER_TEXT="$SCRIPTS/customize-header-text-macos.sh"
IMPORT_THEME="$SCRIPTS/import-theme-package-macos.sh"
EXPORT_THEME="$SCRIPTS/export-theme-package-macos.sh"
[ -x "$APPLY" ] || APPLY="$START"

STATE_ROOT="$HOME/Library/Application Support/CodexDreamSkinStudio"
THEMES_ROOT="$STATE_ROOT/themes"
IMAGES_DIR="$STATE_ROOT/images"
/bin/mkdir -p "$THEMES_ROOT" "$IMAGES_DIR" 2>/dev/null

if [ ! -x "$START" ] && [ ! -x "$APPLY" ]; then
  echo "Skin ?"
  echo "---"
  echo "Engine missing"
  exit 0
fi

TITLE="Skin 关"
THEME_LINE=""
PALETTE_ID_LINE=""
PALETTE_LINE=""
BACKGROUND_LINE=""
LAYOUT_ID_LINE="stage"
LAYOUT_LINE="未来舞台"
PANEL_OPACITY_LINE="76"
PANEL_BLUR_LINE="14"
CODEX_LINE="false"
SESSION_LINE="off"

if [ -x "$STATUS" ]; then
  while IFS= read -r line; do
    case "$line" in
      session=*) SESSION_LINE="${line#session=}" ;;
      codex=*) CODEX_LINE="${line#codex=}" ;;
      theme=*) THEME_LINE="${line#theme=}" ;;
      palette_id=*) PALETTE_ID_LINE="${line#palette_id=}" ;;
      palette=*) PALETTE_LINE="${line#palette=}" ;;
      background=*) BACKGROUND_LINE="${line#background=}" ;;
      layout_id=*) LAYOUT_ID_LINE="${line#layout_id=}" ;;
      layout=*) LAYOUT_LINE="${line#layout=}" ;;
      panel_opacity=*) PANEL_OPACITY_LINE="${line#panel_opacity=}" ;;
      panel_blur=*) PANEL_BLUR_LINE="${line#panel_blur=}" ;;
    esac
  done < <("$STATUS" 2>/dev/null)
  case "$SESSION_LINE" in
    active) TITLE="Skin ON" ;;
    paused) TITLE="Skin 暂停" ;;
    stale|unknown) TITLE="Skin ?" ;;
    *) TITLE="Skin 关" ;;
  esac
fi

echo "$TITLE | sfimage=paintpalette.fill sfcolor=#39C5BB"
echo "---"
echo "布局: $LAYOUT_LINE | color=#4f7379"
if [ -n "$PALETTE_LINE" ]; then
  echo "配色: $PALETTE_LINE | color=#4f7379"
else
  echo "配色: (未设置) | color=#888888"
fi
if [ -n "$BACKGROUND_LINE" ]; then
  echo "背景: $BACKGROUND_LINE | color=#4f7379"
else
  echo "背景: (未设置) | color=#888888"
fi
if [ "$CODEX_LINE" = "true" ]; then
  echo "Codex: 已打开 | color=#888888"
else
  echo "Codex: 未打开 | color=#c45c26"
fi

echo "---"
echo "应用皮肤 | bash=\"$APPLY\" terminal=false refresh=true"
echo "暂停皮肤 | bash=\"$PAUSE\" terminal=false refresh=true"
echo "换一张图… | bash=\"$CUSTOMIZE\" terminal=false refresh=true"
echo "打开主题商店… | href=\"$THEME_STORE_URL\" sfimage=storefront"
if [ -x "$IMPORT_THEME" ]; then
  echo "导入主题包… | bash=\"$IMPORT_THEME\" terminal=false refresh=true sfimage=square.and.arrow.down"
fi
if [ -x "$EXPORT_THEME" ]; then
  echo "导出当前主题… | bash=\"$EXPORT_THEME\" terminal=false refresh=true sfimage=square.and.arrow.up"
fi
if [ -x "$READING_PANEL" ]; then
  echo "阅读区效果: ${PANEL_OPACITY_LINE}% 不透明 · ${PANEL_BLUR_LINE}px 模糊 | color=#4f7379 sfimage=circle.lefthalf.filled"
  echo "调整阅读区磨砂与透明度… | bash=\"$READING_PANEL\" terminal=false refresh=true sfimage=slider.horizontal.3"
fi
if [ -x "$HEADER_TEXT" ]; then
  echo "自定义顶部文字… | bash=\"$HEADER_TEXT\" terminal=false refresh=true sfimage=textformat"
fi

echo "布局主题"
layout_count=0
if [ -x "$SWITCH_LAYOUT" ] && [ -d "$ENGINE/layouts" ]; then
  for layout in "$ENGINE/layouts"/*.json; do
    [ -f "$layout" ] || continue
    lid="$(/usr/bin/basename "$layout" .json)"
    lname="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("name") or sys.argv[2])' "$layout" "$lid" 2>/dev/null)"
    [ -n "$lname" ] || lname="$lid"
    mark=""
    [ "$lid" = "$LAYOUT_ID_LINE" ] && mark=" ✓"
    echo "-- $lname$mark | bash=\"$SWITCH_LAYOUT\" param1=\"--id\" param2=\"$lid\" terminal=false refresh=true"
    layout_count=$((layout_count + 1))
  done
fi
if [ "$layout_count" -eq 0 ]; then
  echo "-- (没有可用布局) | color=#888888"
fi

echo "配色方案"
palette_count=0
if [ -x "$SWITCH_PALETTE" ] && [ -d "$ENGINE/palettes" ]; then
  for palette in "$ENGINE/palettes"/*.json; do
    [ -f "$palette" ] || continue
    pid="$(/usr/bin/basename "$palette" .json)"
    palette_meta="$(/usr/bin/python3 -c 'import json,sys;p=json.load(open(sys.argv[1]));print((p.get("layoutId") or "stage")+"\t"+(p.get("name") or sys.argv[2]))' "$palette" "$pid" 2>/dev/null)"
    palette_layout="${palette_meta%%	*}"
    pname="${palette_meta#*	}"
    [ "$palette_layout" = "$LAYOUT_ID_LINE" ] || continue
    [ -n "$pname" ] || pname="$pid"
    mark=""
    [ "$pid" = "$PALETTE_ID_LINE" ] && mark=" ✓"
    echo "-- $pname$mark | bash=\"$SWITCH_PALETTE\" param1=\"--id\" param2=\"$pid\" terminal=false refresh=true"
    palette_count=$((palette_count + 1))
  done
fi
if [ "$palette_count" -eq 0 ]; then
  echo "-- (没有可用配色) | color=#888888"
fi

# Dynamic: pure images dropped into images/
echo "背景图片"
img_count=0
if [ -d "$IMAGES_DIR" ]; then
  for img in "$IMAGES_DIR"/*; do
    [ -f "$img" ] || continue
    case "$img" in
      *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP) ;;
      *) continue ;;
    esac
    base="$(/usr/bin/basename "$img")"
    mark=""
    if [ "$base" = "$BACKGROUND_LINE" ] || [ "${base%.*}" = "$BACKGROUND_LINE" ]; then mark=" ✓"; fi
    echo "-- $base$mark | bash=\"$LOAD_IMG\" param1=\"--from-library\" param2=\"$base\" terminal=false refresh=true"
    img_count=$((img_count + 1))
  done
fi
if [ "$img_count" -eq 0 ]; then
  echo "-- (把纯背景图放进 images 文件夹) | color=#888888"
fi
echo "-- 打开背景文件夹 | bash=\"/usr/bin/open\" param1=\"$IMAGES_DIR\" terminal=false"

# Legacy combined theme packs remain available for compatibility.
echo "历史组合"
theme_count=0
if [ -d "$THEMES_ROOT" ]; then
  for dir in "$THEMES_ROOT"/*; do
    [ -d "$dir" ] || continue
    [ -f "$dir/theme.json" ] || continue
    tid="$(/usr/bin/basename "$dir")"
    tname="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("name") or sys.argv[2])' "$dir/theme.json" "$tid" 2>/dev/null)"
    [ -n "$tname" ] || tname="$tid"
    mark=""
    [ "$tname" = "$THEME_LINE" ] && mark=" ✓"
    echo "-- $tname$mark | bash=\"$SWITCH\" param1=\"--id\" param2=\"$tid\" terminal=false refresh=true"
    theme_count=$((theme_count + 1))
  done
fi
if [ "$theme_count" -eq 0 ]; then
  echo "-- (还没有，换图后会自动出现) | color=#888888"
fi

echo "---"
echo "完全恢复 | bash=\"$RESTORE\" param1=\"--restore-base-theme\" param2=\"--restart-codex\" terminal=false refresh=true"
echo "---"
echo "刷新 | refresh=true"
