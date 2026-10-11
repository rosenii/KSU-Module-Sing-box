#!/system/bin/sh
BOX=/data/adb/Box
BIN="$BOX/sing-box"
SCRIPTS="$BOX/scripts"
WORK="$BOX/working"
LOG="$WORK/ksu-boot.log"
MP=/data/adb/modules/singbox/module.prop
mkdir -p "$BOX/configs" "$SCRIPTS" "$WORK"

is_running() {
  [ -x "$BIN" ] || return 1
  for p in $(pidof sing-box 2>/dev/null); do
    [ -e "/proc/$p/exe" ] || continue
    e=$(readlink "/proc/$p/exe" 2>/dev/null)
    case "$e" in "$BIN"|"$BIN (deleted)") return 0 ;; esac
  done
  return 1
}
set_description() {
  state="$1"
  [ -f "$MP" ] || return 0
  current=$(grep '^description=' "$MP" 2>/dev/null | head -n 1)
  wanted="description=Sing-Box 状态：$state"
  [ "$current" = "$wanted" ] && return 0
  tmp="$WORK/module.prop.tmp"
  awk -v d="$wanted" 'BEGIN{done=0} /^description=/{if(!done){print d;done=1};next} {print} END{if(!done)print d}' "$MP" > "$tmp" && cat "$tmp" > "$MP"
  rm -f "$tmp"
}

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 5
if [ ! -f "$WORK/selected-config.txt" ] && [ -f "$BOX/configs/config.json" ]; then
  printf '%s\n' 'config.json' > "$WORK/selected-config.txt"
fi
if [ -f "$SCRIPTS/start.sh" ]; then
  echo "[$(date '+%F %T')] KernelSU service: launching detached start script" >> "$LOG"
  if ! is_running; then
    if command -v setsid >/dev/null 2>&1; then
      setsid sh "$SCRIPTS/start.sh" >> "$WORK/ksu-launch.log" 2>&1 </dev/null &
    else
      nohup sh "$SCRIPTS/start.sh" >> "$WORK/ksu-launch.log" 2>&1 </dev/null &
    fi
    sleep 3
  fi
else
  echo "[$(date '+%F %T')] ERROR: $SCRIPTS/start.sh not found" >> "$LOG"
fi
# Update module description once after boot startup; no periodic polling.
if is_running; then
  set_description '运行中'
elif [ -f "$SCRIPTS/start.sh" ]; then
  set_description '已停止'
else
  set_description '已停止（启动脚本缺失）'
fi
exit 0
