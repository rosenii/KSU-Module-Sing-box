#!/system/bin/sh
# Copy this template to /data/adb/Box/scripts/start.sh and adjust only if needed.
BASE="/data/adb/Box"
BIN="$BASE/sing-box"
CONFIG_DIR="$BASE/configs"
WORK_DIR="$BASE/working"
SELECTED="$WORK_DIR/selected-config.txt"
PIDFILE="$WORK_DIR/sing-box.pid"
LOG="$WORK_DIR/sing-box.log"
ACTIVE="$WORK_DIR/active-config.txt"

mkdir -p "$WORK_DIR"

# Read the selected filename (not a path) from the WebUI selection file.
if [ -f "$SELECTED" ]; then
    working="$(cat "$SELECTED" 2>/dev/null | tr -d '\r\n')"
else
    working="config.json"
fi

# Strict filename validation prevents path traversal.
case "$working" in
    ""|*/*|*\\*|.*)
        echo "[$(date '+%F %T')] Invalid config filename: $working" >> "$LOG"
        exit 1
        ;;
esac
case "$working" in
    *.json) ;;
    *) echo "[$(date '+%F %T')] Config must end with .json: $working" >> "$LOG"; exit 1 ;;
esac

CONFIG="$CONFIG_DIR/$working"
[ -x "$BIN" ] || { echo "[$(date '+%F %T')] Binary missing/not executable: $BIN" >> "$LOG"; exit 1; }
[ -f "$CONFIG" ] || { echo "[$(date '+%F %T')] Config not found: $CONFIG" >> "$LOG"; exit 1; }

# Prevent duplicate launch of this exact binary.
if [ -f "$PIDFILE" ]; then
    oldpid="$(cat "$PIDFILE" 2>/dev/null)"
    case "$oldpid" in ''|*[!0-9]*) oldpid="" ;; esac
    if [ -n "$oldpid" ] && [ -r "/proc/$oldpid/exe" ]; then
        oldexe="$(readlink "/proc/$oldpid/exe" 2>/dev/null)"
        case "$oldexe" in
            "$BIN"|"$BIN (deleted)")
                echo "[$(date '+%F %T')] Already running, PID=$oldpid" >> "$LOG"
                exit 0
                ;;
        esac
    fi
    rm -f "$PIDFILE"
fi

if ! "$BIN" check -c "$CONFIG" >> "$LOG" 2>&1; then
    echo "[$(date '+%F %T')] Config check failed: $working" >> "$LOG"
    exit 1
fi

echo "[$(date '+%F %T')] Starting with config: $working" >> "$LOG"
# Record the actual config selected for this running instance.
printf '%s\n' "$working" > "$ACTIVE"
nohup "$BIN" run -c "$CONFIG" >> "$LOG" 2>&1 </dev/null &
pid=$!
printf '%s\n' "$pid" > "$PIDFILE"
sleep 2

if [ -r "/proc/$pid/exe" ]; then
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null)"
    case "$exe" in
        "$BIN"|"$BIN (deleted)")
            echo "[$(date '+%F %T')] Started, PID=$pid, config=$working" >> "$LOG"
            exit 0
            ;;
    esac
fi

echo "[$(date '+%F %T')] Start failed or process exited; check log" >> "$LOG"
rm -f "$PIDFILE" "$ACTIVE"
exit 1
