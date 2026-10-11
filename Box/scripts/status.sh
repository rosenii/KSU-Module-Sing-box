#!/system/bin/sh

BASE=/data/adb/Box
WORK=/data/adb/Box/working
BIN="$BASE/sing-box"
CONF="$WORK/working.json"
LOG="$WORK/sing-box.log"
PIDFILE="$WORK/sing-box.pid"

echo "===== sing-box 运行状态 ====="

if [ ! -x "$BIN" ]; then
    echo "状态：失败"
    echo "原因：二进制文件不存在或不可执行"
    exit 1
fi

if [ ! -f "$CONF" ]; then
    echo "状态：失败"
    echo "原因：配置文件不存在"
    exit 1
fi

if [ ! -f "$PIDFILE" ]; then
    echo "状态：未运行"
    echo "原因：PID 文件不存在"
    exit 1
fi

PID="$(cat "$PIDFILE" 2>/dev/null)"

case "$PID" in
    ''|*[!0-9]*)
        echo "状态：异常"
        echo "原因：PID 文件内容无效"
        exit 1
        ;;
esac

if ! kill -0 "$PID" 2>/dev/null; then
    echo "状态：未运行"
    echo "原因：进程已退出"
    rm -f "$PIDFILE"
    exit 1
fi

EXE="$(readlink "/proc/$PID/exe" 2>/dev/null)"

case "$EXE" in
    "$BIN"|"$BIN (deleted)")
        echo "状态：运行中"
        echo "PID：$PID"
        echo "配置：$CONF"
        echo "日志：$LOG"
        ;;
    *)
        echo "状态：异常"
        echo "原因：PID 对应的执行文件不匹配"
        echo "实际路径：$EXE"
        echo "预期路径：$BIN"
        exit 1
        ;;
esac

echo
echo "最近 10 行日志："
tail -n 10 "$LOG" 2>/dev/null

exit 0