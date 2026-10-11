#!/system/bin/sh
BOX=/data/adb/Box
if [ -x "$BOX/scripts/stop.sh" ]; then
  sh "$BOX/scripts/stop.sh" >/dev/null 2>&1
fi
# Preserve all files under /data/adb/Box.
