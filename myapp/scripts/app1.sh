#!/bin/bash
# /opt/scripts/app1.sh
# Called by systemd ExecStart/ExecStop/ExecReload
# Also called directly by ops team
# Both share /opt/pids/app1.pid

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────
APP_NAME="app1"
APP_DIR="/opt/myapp"
VENV="/opt/venvs/app1"
ENV_FILE="/opt/envs/app1.env"
CONF="/opt/configs/gunicorn/app1.conf.py"

# Shared PID file — systemd PIDFile= and this script both use this
PID_FILE="/opt/pids/app1.pid"

LOG_DIR="/opt/logs/app1"
PORT="8001"
GUNICORN="$VENV/bin/gunicorn"
STARTUP_LOG="$LOG_DIR/startup.log"

# ── Detect if running under systemd ──────────────────────────────
# INVOCATION_ID is set by systemd for every unit invocation
UNDER_SYSTEMD=false
[ -n "${INVOCATION_ID:-}" ] && UNDER_SYSTEMD=true

# ── Helpers ───────────────────────────────────────────────────────
log() {
    local msg="[$APP_NAME] $1"
    if $UNDER_SYSTEMD; then
        # systemd captures stdout/stderr into journald
        echo "$msg"
    else
        # Direct run — print with timestamp
        echo "$(date '+%Y-%m-%d %H:%M:%S') $msg"
    fi
}

is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null
}

get_pid() {
    cat "$PID_FILE" 2>/dev/null || echo ""
}

wait_for_pid() {
    # Wait until gunicorn writes PID file
    local timeout=30
    local count=0
    while [ $count -lt $timeout ]; do
        [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null && return 0
        sleep 1
        count=$((count + 1))
    done
    return 1
}

wait_for_stop() {
    local pid=$1
    local timeout=30
    local count=0
    while [ $count -lt $timeout ]; do
        kill -0 "$pid" 2>/dev/null || return 0
        log "Waiting for PID $pid to stop ($count/$timeout)"
        sleep 1
        count=$((count + 1))
    done
    return 1
}

ensure_dirs() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$(dirname $PID_FILE)"
    chown -R "${APP_USER:-wlsapps}":"${APP_GROUP:-wlsapps}" \
        "$LOG_DIR" "$(dirname $PID_FILE)" 2>/dev/null || true
}

# ── START ─────────────────────────────────────────────────────────
start() {
    log "Starting ($( $UNDER_SYSTEMD && echo 'via systemd' || echo 'direct'))"

    # Guard: already running
    if is_running; then
        log "Already running — PID: $(get_pid)"
        # Return 0 so systemd does not fail if called twice
        exit 0
    fi

    # Guard: stale pid file
    if [ -f "$PID_FILE" ]; then
        log "Removing stale PID file: $PID_FILE"
        rm -f "$PID_FILE"
    fi

    # Guard: port in use
    if ss -tlnp | grep -q ":$PORT"; then
        log "ERROR: Port $PORT already in use"
        ss -tlnp | grep ":$PORT"
        exit 1
    fi

    # Guard: orphan gunicorn masters
    ORPHANS=$(pgrep -f "gunicorn: master" 2>/dev/null || true)
    if [ -n "$ORPHANS" ]; then
        log "WARNING: Orphan gunicorn masters found: $ORPHANS — killing"
        pkill -TERM -f "gunicorn: master" 2>/dev/null || true
        sleep 2
    fi

    ensure_dirs

    # Load .env
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck source=/dev/null
        source "$ENV_FILE"
        set +a
        log "Loaded env: $ENV_FILE"
    else
        log "WARNING: $ENV_FILE not found — using shell environment"
    fi

    cd "$APP_DIR"

    if $UNDER_SYSTEMD; then
        # ── systemd mode ─────────────────────────────────────────
        # systemd tracks the process directly via PIDFile=
        # Do NOT use nohup or & — systemd wants the foreground process
        # gunicorn.conf.py has daemon=False
        log "Starting gunicorn in foreground (systemd mode)"
        exec "$GUNICORN" \
            "wsgi:application" \
            --config "$CONF"
            # exec replaces shell process with gunicorn
            # systemd now tracks gunicorn master directly
    else
        # ── Direct mode ──────────────────────────────────────────
        # Run in background — ops team invoked directly
        log "Starting gunicorn in background (direct mode)"
        nohup "$GUNICORN" \
            "wsgi:application" \
            --config "$CONF" \
            > "$STARTUP_LOG" 2>&1 &

        # Wait for PID file to appear
        if wait_for_pid; then
            log "Started — PID: $(get_pid) | Port: $PORT"
            log "Logs   : $LOG_DIR"
        else
            log "FAILED to start — check $STARTUP_LOG"
            exit 1
        fi
    fi
}

# ── STOP ──────────────────────────────────────────────────────────
stop() {
    log "Stopping ($( $UNDER_SYSTEMD && echo 'via systemd' || echo 'direct'))"

    if ! is_running; then
        log "Not running — nothing to stop"
        rm -f "$PID_FILE"
        exit 0
    fi

    local pid
    pid=$(get_pid)
    log "Sending SIGTERM to PID: $pid"
    kill -TERM "$pid" 2>/dev/null || true

    if wait_for_stop "$pid"; then
        log "Stopped gracefully"
    else
        log "Graceful stop timed out — sending SIGKILL to PID: $pid"
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    log "PID file removed"
}

# ── RELOAD ────────────────────────────────────────────────────────
reload() {
    log "Reloading workers (USR1 — zero downtime)"

    if ! is_running; then
        log "Not running — cannot reload"
        exit 1
    fi

    local pid
    pid=$(get_pid)
    kill -USR1 "$pid" 2>/dev/null
    log "USR1 sent to PID: $pid — workers reopening log files"
}

# ── RESTART ───────────────────────────────────────────────────────
restart() {
    log "Restarting"
    stop
    sleep 2
    start
}

# ── STATUS ────────────────────────────────────────────────────────
status() {
    echo "=== [$APP_NAME] Status ==="
    echo "  PID file     : $PID_FILE"
    echo "  Under systemd: $UNDER_SYSTEMD"
    echo ""

    if is_running; then
        local pid
        pid=$(get_pid)
        local workers
        workers=$(pgrep -c -P "$pid" 2>/dev/null || echo 0)
        echo "  Status  : RUNNING"
        echo "  PID     : $pid"
        echo "  Workers : $workers"
        echo "  Port    : $PORT"
        echo "  Uptime  : $(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ' || echo unknown)"
    else
        echo "  Status  : STOPPED"
    fi

    echo ""
    echo "  Port $PORT:"
    ss -tlnp | grep ":$PORT" || echo "  Nothing on :$PORT"

    echo ""
    echo "  Gunicorn masters:"
    pgrep -a -f "gunicorn: master" || echo "  None running"

    if $UNDER_SYSTEMD || systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
        echo ""
        echo "  systemd status:"
        systemctl status "$APP_NAME" --no-pager -l 2>/dev/null || true
    fi
}

# ── Entry point ───────────────────────────────────────────────────
case "${1:-}" in
    start)    start   ;;
    stop)     stop    ;;
    restart)  restart ;;
    reload)   reload  ;;
    status)   status  ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status}"
        exit 1
        ;;
esac