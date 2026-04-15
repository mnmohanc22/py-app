#!/bin/bash
# /opt/scripts/app1.sh

APP_NAME="app1"
APP_DIR="/opt/myapp"                    # source code
VENV="/opt/venvs/app1"                  # virtualenv
ENV_FILE="/opt/envs/app1.env"           # env file
CONF="/opt/configs/gunicorn/app1.conf.py"

# ── External dirs — nothing inside source ────────────────────────
PID_FILE="/var/run/myapp/app1.pid"      # outside source
LOG_DIR="/var/log/myapp"                # outside source
PORT="8001"

GUNICORN="$VENV/bin/gunicorn"
STARTUP_LOG="$LOG_DIR/startup.log"
UNDER_SYSTEMD=false
[ -n "${INVOCATION_ID:-}" ] && UNDER_SYSTEMD=true

log() {
    $UNDER_SYSTEMD \
        && echo "[$APP_NAME] $1" \
        || echo "$(date '+%Y-%m-%d %H:%M:%S') [$APP_NAME] $1"
}

is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null
}

get_pid() {
    cat "$PID_FILE" 2>/dev/null || echo ""
}

ensure_dirs() {
    # Create external dirs if not present
    mkdir -p "$LOG_DIR"
    mkdir -p "$(dirname $PID_FILE)"
    chown -R wlsapps:wlsapps "$LOG_DIR" "$(dirname $PID_FILE)" 2>/dev/null || true
}

start() {
    log "Starting..."
    is_running && { log "Already running — PID: $(get_pid)"; exit 0; }
    [ -f "$PID_FILE" ] && { log "Removing stale PID file"; rm -f "$PID_FILE"; }

    if ss -tlnp | grep -q ":$PORT"; then
        log "ERROR: Port $PORT in use"
        exit 1
    fi

    ensure_dirs

    [ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

    cd "$APP_DIR"

    if $UNDER_SYSTEMD; then
        log "Foreground mode (systemd)"
        exec "$GUNICORN" "wsgi:application" --config "$CONF"
    else
        log "Background mode (direct)"
        nohup "$GUNICORN" "wsgi:application" --config "$CONF" \
            > "$STARTUP_LOG" 2>&1 &

        # Wait for PID file
        for i in {1..30}; do
            [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null && {
                log "Started — PID: $(get_pid) | Logs: $LOG_DIR"
                exit 0
            }
            sleep 1
        done
        log "FAILED — check $STARTUP_LOG"
        exit 1
    fi
}

stop() {
    log "Stopping..."
    if ! is_running; then
        log "Not running"
        rm -f "$PID_FILE"
        exit 0
    fi

    local pid
    pid=$(get_pid)
    kill -TERM "$pid"

    for i in {1..30}; do
        kill -0 "$pid" 2>/dev/null || {
            log "Stopped"
            rm -f "$PID_FILE"
            exit 0
        }
        sleep 1
    done

    log "Force killing PID: $pid"
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
}

reload() {
    is_running || { log "Not running"; exit 1; }
    log "Reloading — USR1 to PID: $(get_pid)"
    kill -USR1 "$(get_pid)"
}

restart() { stop; sleep 2; start; }

status() {
    echo "=== [$APP_NAME] ==="
    echo "  Source   : $APP_DIR"
    echo "  Logs     : $LOG_DIR"
    echo "  PID file : $PID_FILE"
    echo ""
    if is_running; then
        local pid; pid=$(get_pid)
        echo "  Status   : RUNNING"
        echo "  PID      : $pid"
        echo "  Workers  : $(pgrep -c -P $pid 2>/dev/null || echo 0)"
        echo "  Uptime   : $(ps -p $pid -o etime= 2>/dev/null | tr -d ' ')"
    else
        echo "  Status   : STOPPED"
    fi
    echo ""
    echo "  Log files:"
    ls -lh "$LOG_DIR"/*.log 2>/dev/null || echo "  No logs yet"
}

case "${1:-}" in
    start|stop|restart|reload|status) "$1" ;;
    *) echo "Usage: $0 {start|stop|restart|reload|status}"; exit 1 ;;
esac