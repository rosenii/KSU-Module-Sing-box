#!/system/bin/sh

BASE=/data/adb/Box
PIDFILE="$BASE/working/sing-box.pid"
BIN="$BASE/sing-box"

if [ ! -f "$PIDFILE" ]; then
    echo "PID 文件不存在，sing-box 可能未运行"
    exit 1
fi

PID="$(cat "$PIDFILE" 2>/dev/null)"

case "$PID" in
    ''|*[!0-9]*)
        echo "PID 文件无效"
        exit 1
        ;;
esac

if ! kill -0 "$PID" 2>/dev/null; then
    echo "进程已退出，清理 PID 文件"
    rm -f "$PIDFILE"
    exit 0
fi

# 获取进程实际执行文件，避免严格匹配 cmdline 参数
EXE="$(readlink "/proc/$PID/exe" 2>/dev/null)"

case "$EXE" in
    "$BIN"|"$BIN (deleted)")
        ;;
    *)
        echo "拒绝停止：PID $PID 的执行文件不匹配"
        echo "实际执行文件：$EXE"
        echo "预期执行文件：$BIN"
        exit 1
        ;;
esac

echo "正在停止 sing-box，PID=$PID"
kill -TERM "$PID" || {
    echo "发送停止信号失败"
    exit 1
}

i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done

if kill -0 "$PID" 2>/dev/null; then
    echo "进程 10 秒内未退出，保留 PID 文件"
    exit 1
fi

rm -f "$PIDFILE"
echo "sing-box 已停止"
exit 0