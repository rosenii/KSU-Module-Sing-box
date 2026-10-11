#!/system/bin/sh
BOX=/data/adb/Box
BIN="$BOX/sing-box"
SCRIPTS="$BOX/scripts"
WORK="$BOX/working"
LOG="$WORK/ksu-action.log"
MP=/data/adb/modules/singbox/module.prop
mkdir -p "$WORK"
is_running() {
  [ -x "$BIN" ] || return 1
  for p in $(pidof sing-box 2>/dev/null); do
    [ -e "/proc/$p/exe" ] || continue
    exe=$(readlink "/proc/$p/exe" 2>/dev/null)
    case "$exe" in "$BIN"|"$BIN (deleted)") return 0 ;; esac
  done
  return 1
}
set_description() {
  if is_running; then state='运行中'; else state='已停止'; fi
  [ -f "$MP" ] || return 0
  sed "s/^description=.*/description=Sing-Box 状态：$state/" "$MP" > "$WORK/module.prop.tmp" && cat "$WORK/module.prop.tmp" > "$MP"
  rm -f "$WORK/module.prop.tmp"
}
if is_running; then
  echo "[$(date '+%F %T')] Action: stopping sing-box" >> "$LOG"
  sh "$SCRIPTS/stop.sh" >> "$LOG" 2>&1
  sleep 1
  echo "Sing-Box 已执行停止。"
else
  [ -f "$WORK/selected-config.txt" ] || { [ -f "$BOX/configs/config.json" ] && printf '%s\n' 'config.json' > "$WORK/selected-config.txt"; }
  echo "[$(date '+%F %T')] Action: starting sing-box" >> "$LOG"
  sh "$SCRIPTS/start.sh" >> "$LOG" 2>&1
  echo "已执行 Sing-Box 启动脚本。"
fi
sleep 1
set_description
