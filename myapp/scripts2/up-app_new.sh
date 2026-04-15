#!/bin/bash
# /opt/scripts/app1.sh
# Manages gunicorn lifecycle
# Reads all paths from bootstrap.vars
# Re-execs as APP_USER if not already running as app user
# Usage: ./app1.sh {start|stop|restart|reload|status}

set -euo pipefail

# ════════════════════════════════════════════════════════════════
# RESOLVE SCRIPTS BASE DIR
# ════════════════════════════════════════════════════════════════
if command -v realpath &>/dev/null; then
    SCRIPTS_BASE="$(dirname "$(realpath "$0")")"
else
    SCRIPTS_BASE="$(cd "$(dirname "$0")" && pwd)"
fi

BOOTSTRAP_VARS="$SCRIPTS_BASE/bootstrap.vars"

# ════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[app1]${NC} $1"; }
success() { echo -e "${GREEN}[app1] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[app1] ⚠${NC} $1"; }
error()   { echo -e "${RED}[app1] ✗${NC} $1"; }
die()     { error "$1"; exit 1; }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }

# ════════════════════════════════════════════════════════════════
# LOAD read_env.sh
# ════════════════════════════════════════════════════════════════
load_read_env() {
    local read_env="$SCRIPTS_BASE/read_env.sh"

    [ -f "$read_env" ] \
        || die "read_env.sh not found: $read_env"

    [ -r "$read_env" ] \
        || die "read_env.sh not readable: $read_env
    Fix: chmod 644 $read_env"

    # Fix CRLF
    file "$read_env" | grep -q "CRLF" \
        && sed -i 's/\r//' "$read_env"

    # shellcheck source=/dev/null
    source "$read_env"

    declare -f load_env > /dev/null 2>&1 \
        || die "load_env function not found after sourcing $read_env"
}

# ════════════════════════════════════════════════════════════════
# LOAD bootstrap.vars
# ════════════════════════════════════════════════════════════════
load_bootstrap_vars() {
    [ -f "$BOOTSTRAP_VARS" ] \
        || die "bootstrap.vars not found: $BOOTSTRAP_VARS"

    [ -r "$BOOTSTRAP_VARS" ] \
        || die "bootstrap.vars not readable: $BOOTSTRAP_VARS"

    # Fix CRLF
    file "$BOOTSTRAP_VARS" | grep -q "CRLF" \
        && sed -i 's/\r//' "$BOOTSTRAP_VARS"

    load_env "$BOOTSTRAP_VARS"
    log "bootstrap.vars loaded from: $BOOTSTRAP_VARS"
}

# ════════════════════════════════════════════════════════════════
# RE-EXEC AS APP_USER
# ════════════════════════════════════════════════════════════════
ensure_app_user() {
    local target_user="${APP_USER:-wlsapps}"
    local current_user
    current_user=$(whoami)

    # Already correct user — nothing to do
    if [ "$current_user" = "$target_user" ]; then
        success "Running as: $current_user"
        return 0
    fi

    log "Currently: $current_user → Re-execing as: $target_user"

    # Guard: sudo available
    command -v sudo &>/dev/null \
        || die "sudo not found — cannot switch to $target_user"

    # Guard: can sudo to target user
    sudo -u "$target_user" -n true > /dev/null 2>&1 \
        || die "Cannot sudo to $target_user
    Fix: add to /etc/sudoers.d/myapp:
         $(whoami) ALL=($target_user) NOPASSWD: $0"

    # Re-exec as APP_USER with same command
    exec sudo -u "$target_user" \
        BOOTSTRAP_VARS="$BOOTSTRAP_VARS" \
        "$0" "$COMMAND"

    die "exec failed — could not re-run as $target_user"
}

# ════════════════════════════════════════════════════════════════
# RESOLVE ALL PATHS FROM PROJECT_ROOT
# ════════════════════════════════════════════════════════════════
resolve_paths() {

    # Guard: PROJECT_ROOT defined
    [ -n "${PROJECT_ROOT:-}" ] \
        || die "PROJECT_ROOT not set in bootstrap.vars"

    # Guard: PROJECT_ROOT exists
    [ -d "$PROJECT_ROOT" ] \
        || die "PROJECT_ROOT not found: $PROJECT_ROOT
    Run: $SCRIPTS_BASE/bootstrap.sh"

    # ── Resolve all dirs from PROJECT_ROOT ────────────────────────
    APP_DIR="$PROJECT_ROOT/${APP_RELATIVE:-app}"
    RELEASES_DIR="$PROJECT_ROOT/${RELEASES_RELATIVE:-releases}"
    VENV_DIR="$PROJECT_ROOT/${VENV_RELATIVE:-venv}"
    LOG_DIR="$PROJECT_ROOT/${LOGS_RELATIVE:-logs}"
    RUN_DIR="$PROJECT_ROOT/${RUN_RELATIVE:-run}"
    CONFIGS_DIR="$PROJECT_ROOT/${CONFIGS_RELATIVE:-configs}"
    GUNICORN_CONF_DIR="$PROJECT_ROOT/${GUNICORN_CONF_RELATIVE:-configs/gunicorn}"

    # ── Key files ─────────────────────────────────────────────────
    PID_FILE="$RUN_DIR/${APP_NAME:-myapp}.pid"
    CONF_FILE="$GUNICORN_CONF_DIR/gunicorn.conf.py"
    GUNICORN_BIN="$VENV_DIR/bin/gunicorn"
    STARTUP_LOG="$LOG_DIR/startup.log"

    # ── Systemd detection ─────────────────────────────────────────
    UNDER_SYSTEMD=false
    [ -n "${INVOCATION_ID:-}" ] && UNDER_SYSTEMD=true

    log "Paths resolved from PROJECT_ROOT=$PROJECT_ROOT"
}

# ════════════════════════════════════════════════════════════════
# VALIDATE REQUIRED PATHS
# ════════════════════════════════════════════════════════════════
validate_paths() {
    local errors=0

    echo ""
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │              Resolved Paths                              │"
    echo "  ├────────────────────────────┬─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "PROJECT_ROOT"   "$PROJECT_ROOT"
    printf "  │  %-26s │ %s\n" "APP_DIR"        "$APP_DIR"
    printf "  │  %-26s │ %s\n" "RELEASES_DIR"   "$RELEASES_DIR"
    printf "  │  %-26s │ %s\n" "VENV_DIR"       "$VENV_DIR"
    printf "  │  %-26s │ %s\n" "LOG_DIR"        "$LOG_DIR"
    printf "  │  %-26s │ %s\n" "RUN_DIR"        "$RUN_DIR"
    printf "  │  %-26s │ %s\n" "PID_FILE"       "$PID_FILE"
    printf "  │  %-26s │ %s\n" "CONF_FILE"      "$CONF_FILE"
    printf "  │  %-26s │ %s\n" "GUNICORN_BIN"   "$GUNICORN_BIN"
    printf "  │  %-26s │ %s\n" "ENV_FILE"       "${ENV_FILE:-NOT SET}"
    printf "  │  %-26s │ %s\n" "UNDER_SYSTEMD"  "$UNDER_SYSTEMD"
    printf "  │  %-26s │ %s\n" "Running as"     "$(whoami)"
    echo "  └────────────────────────────┴─────────────────────────────┘"
    echo ""

    # Check required dirs
    for item in \
        "APP_DIR:$APP_DIR:d" \
        "VENV_DIR:$VENV_DIR:d" \
        "GUNICORN_BIN:$GUNICORN_BIN:f" \
        "CONF_FILE:$CONF_FILE:f"; do

        label="${item%%:*}"
        rest="${item#*:}"
        path="${rest%%:*}"
        type="${rest##*:}"

        if [ "$type" = "d" ] && [ ! -d "$path" ]; then
            error "$label not found: $path"
            errors=$((errors + 1))
        elif [ "$type" = "f" ] && [ ! -f "$path" ]; then
            error "$label not found: $path"
            errors=$((errors + 1))
        else
            success "$label: $path"
        fi
    done

    [ $errors -eq 0 ] \
        || die "$errors missing path(s).
    Run: $SCRIPTS_BASE/bootstrap.sh
    Then: $SCRIPTS_BASE/deploy.sh --branch main
    Then: $SCRIPTS_BASE/create_venv.sh"
}

# ════════════════════════════════════════════════════════════════
# EXPORT PROJECT VARS FOR gunicorn.conf.py
# gunicorn.conf.py reads these from os.environ
# Must be called before exec gunicorn
# ════════════════════════════════════════════════════════════════
export_project_vars() {
    section "Exporting project vars for gunicorn.conf.py"

    # ── Core project structure ────────────────────────────────────
    export PROJECT_ROOT
    export APP_NAME

    # ── Relative dir names ────────────────────────────────────────
    # gunicorn.conf.py uses these to resolve absolute paths
    export APP_RELATIVE
    export RELEASES_RELATIVE
    export VENV_RELATIVE
    export CONFIGS_RELATIVE
    export GUNICORN_CONF_RELATIVE

    # ── Log dir — gunicorn writes access + error logs here ────────
    export LOGS_RELATIVE
    # gunicorn.conf.py resolves: LOG_DIR = PROJECT_ROOT/LOGS_RELATIVE
    # accesslog = LOG_DIR/gunicorn-access.log
    # errorlog  = LOG_DIR/gunicorn-error.log

    # ── Run dir — gunicorn writes pid file here ───────────────────
    export RUN_RELATIVE
    # gunicorn.conf.py resolves: RUN_DIR  = PROJECT_ROOT/RUN_RELATIVE
    # pidfile   = RUN_DIR/APP_NAME.pid

    # ── Env file path ─────────────────────────────────────────────
    export ENV_FILE

    # ── Gunicorn tunables — read by gunicorn.conf.py ──────────────
    export GUNICORN_BIND
    export GUNICORN_WORKERS
    export GUNICORN_THREADS
    export GUNICORN_TIMEOUT
    export LOG_LEVEL

    # ── Print summary of what was exported ───────────────────────
    echo ""
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │         Exported Vars → gunicorn.conf.py                 │"
    echo "  ├────────────────────────────┬─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "PROJECT_ROOT"           "$PROJECT_ROOT"
    printf "  │  %-26s │ %s\n" "APP_NAME"                "$APP_NAME"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "APP_RELATIVE"            "$APP_RELATIVE"
    printf "  │  %-26s │ %s\n" "RELEASES_RELATIVE"       "$RELEASES_RELATIVE"
    printf "  │  %-26s │ %s\n" "VENV_RELATIVE"           "$VENV_RELATIVE"
    printf "  │  %-26s │ %s\n" "CONFIGS_RELATIVE"        "$CONFIGS_RELATIVE"
    printf "  │  %-26s │ %s\n" "GUNICORN_CONF_RELATIVE"  "$GUNICORN_CONF_RELATIVE"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "LOGS_RELATIVE"           "$LOGS_RELATIVE"
    printf "  │  %-26s │ → %s\n" "  resolved LOG_DIR"    "$LOG_DIR"
    printf "  │  %-26s │ → %s\n" "  accesslog"           "$LOG_DIR/gunicorn-access.log"
    printf "  │  %-26s │ → %s\n" "  errorlog"            "$LOG_DIR/gunicorn-error.log"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "RUN_RELATIVE"            "$RUN_RELATIVE"
    printf "  │  %-26s │ → %s\n" "  resolved RUN_DIR"    "$RUN_DIR"
    printf "  │  %-26s │ → %s\n" "  pidfile"             "$PID_FILE"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "ENV_FILE"                "$ENV_FILE"
    printf "  │  %-26s │ %s\n" "GUNICORN_BIND"           "${GUNICORN_BIND:-0.0.0.0:8001}"
    printf "  │  %-26s │ %s\n" "GUNICORN_WORKERS"        "${GUNICORN_WORKERS:-auto}"
    printf "  │  %-26s │ %s\n" "GUNICORN_THREADS"        "${GUNICORN_THREADS:-2}"
    printf "  │  %-26s │ %s\n" "GUNICORN_TIMEOUT"        "${GUNICORN_TIMEOUT:-120}"
    printf "  │  %-26s │ %s\n" "LOG_LEVEL"               "${LOG_LEVEL:-info}"
    echo "  └────────────────────────────┴─────────────────────────────┘"
    echo ""

    success "Project vars exported"
}

# ════════════════════════════════════════════════════════════════
# LOAD .env FILE
# app1.sh is single source of truth for loading .env
# gunicorn.conf.py and wsgi.py read os.environ only
# ════════════════════════════════════════════════════════════════
load_env_file() {
    section "Loading .env"

    [ -n "${ENV_FILE:-}" ] \
        || die "ENV_FILE not set in bootstrap.vars"

    [ -f "$ENV_FILE" ] \
        || die ".env not found: $ENV_FILE
    Create: cp $APP_DIR/.env.example $ENV_FILE
    Edit  : vi $ENV_FILE"

    [ -r "$ENV_FILE" ] \
        || die ".env not readable: $ENV_FILE
    Fix: chmod 640 $ENV_FILE"

    # Export all vars from .env into shell environment
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a

    success ".env loaded: $ENV_FILE"
}

# ════════════════════════════════════════════════════════════════
# PROCESS HELPERS
# ════════════════════════════════════════════════════════════════
is_running() {
    [ -f "$PID_FILE" ] \
        && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

get_pid() {
    cat "$PID_FILE" 2>/dev/null || echo ""
}

get_worker_count() {
    local pid="${1:-}"
    [ -z "$pid" ] && echo "0" && return
    pgrep -c -P "$pid" 2>/dev/null || echo "0"
}

wait_for_pid() {
    local timeout="${1:-30}"
    local count=0
    while [ "$count" -lt "$timeout" ]; do
        [ -f "$PID_FILE" ] \
            && kill -0 "$(cat "$PID_FILE")" 2>/dev/null \
            && return 0
        sleep 1
        count=$((count + 1))
    done
    return 1
}

wait_for_stop() {
    local pid="$1"
    local timeout="${2:-30}"
    local count=0
    while [ "$count" -lt "$timeout" ]; do
        kill -0 "$pid" 2>/dev/null || return 0
        log "Waiting for PID $pid to stop ($count/$timeout)..."
        sleep 1
        count=$((count + 1))
    done
    return 1
}

ensure_runtime_dirs() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$RUN_DIR"
    success "Runtime dirs ready:"
    success "  LOG_DIR: $LOG_DIR"
    success "  RUN_DIR: $RUN_DIR"
}

# ════════════════════════════════════════════════════════════════
# START
# ════════════════════════════════════════════════════════════════
start() {
    section "START $APP_NAME"

    # Guard: already running
    if is_running; then
        warn "Already running — PID: $(get_pid)"
        exit 0
    fi

    # Guard: stale pid file
    if [ -f "$PID_FILE" ]; then
        warn "Stale PID file found — removing: $PID_FILE"
        rm -f "$PID_FILE"
    fi

    # Guard: port already in use
    local port
    port=$(echo "${GUNICORN_BIND:-0.0.0.0:8001}" | cut -d: -f2)
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        error "Port $port already in use"
        ss -tlnp | grep ":$port"
        die "Free port $port before starting"
    fi

    # Guard: orphan gunicorn masters
    local orphans
    orphans=$(pgrep -f "gunicorn: master" 2>/dev/null || true)
    if [ -n "$orphans" ]; then
        warn "Orphan gunicorn masters found — killing: $orphans"
        pkill -TERM -f "gunicorn: master" 2>/dev/null || true
        sleep 2
    fi

    # Ensure LOG_DIR and RUN_DIR exist
    ensure_runtime_dirs

    # Load .env — populates os.environ
    load_env_file

    # Export project vars — gunicorn.conf.py reads these
    export_project_vars

    # Change to APP_DIR — wsgi.py must be found here
    cd "$APP_DIR"
    log "Working dir: $(pwd)"
    log "Gunicorn   : $GUNICORN_BIN"
    log "Config     : $CONF_FILE"

    if $UNDER_SYSTEMD; then
        # ── Systemd mode ─────────────────────────────────────────
        # exec replaces shell — systemd tracks gunicorn master
        section "Starting in foreground (systemd)"
        exec "$GUNICORN_BIN" \
            "wsgi:application" \
            --config "$CONF_FILE"

    else
        # ── Direct mode ──────────────────────────────────────────
        section "Starting in background (direct)"
        log "Startup log: $STARTUP_LOG"

        nohup "$GUNICORN_BIN" \
            "wsgi:application" \
            --config "$CONF_FILE" \
            > "$STARTUP_LOG" 2>&1 &

        # Wait for PID file
        if wait_for_pid 30; then
            local pid workers
            pid=$(get_pid)
            workers=$(get_worker_count "$pid")

            echo ""
            success "Started successfully"
            echo ""
            printf "  %-22s %s\n" "PID:"          "$pid"
            printf "  %-22s %s\n" "Workers:"      "$workers"
            printf "  %-22s %s\n" "Port:"         "$port"
            printf "  %-22s %s\n" "PID file:"     "$PID_FILE"
            printf "  %-22s %s\n" "Access log:"   "$LOG_DIR/gunicorn-access.log"
            printf "  %-22s %s\n" "Error log:"    "$LOG_DIR/gunicorn-error.log"
            printf "  %-22s %s\n" "App log:"      "$LOG_DIR/app.log"
            printf "  %-22s %s\n" "Startup log:"  "$STARTUP_LOG"
            echo ""
        else
            error "Failed to start — check startup log"
            echo ""
            echo "  Last 20 lines of $STARTUP_LOG:"
            tail -20 "$STARTUP_LOG" 2>/dev/null \
                | awk '{printf "  %s\n", $0}' \
                || echo "  (no startup log found)"
            echo ""
            exit 1
        fi
    fi
}

# ════════════════════════════════════════════════════════════════
# STOP
# ════════════════════════════════════════════════════════════════
stop() {
    section "STOP $APP_NAME"
    log "PID file: $PID_FILE"

    if ! is_running; then
        warn "Not running — nothing to stop"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid=$(get_pid)
    log "Sending SIGTERM to master PID: $pid"
    kill -TERM "$pid" 2>/dev/null || true

    if wait_for_stop "$pid" 30; then
        success "Stopped gracefully — PID: $pid"
        rm -f "$PID_FILE"
    else
        warn "Graceful stop timed out — sending SIGKILL to PID: $pid"
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        success "Force killed — PID: $pid"
    fi
}

# ════════════════════════════════════════════════════════════════
# RESTART
# ════════════════════════════════════════════════════════════════
restart() {
    section "RESTART $APP_NAME"
    log "Project root: $PROJECT_ROOT"
    stop
    sleep 2
    start
}

# ════════════════════════════════════════════════════════════════
# RELOAD — zero downtime log reopen (USR1)
# ════════════════════════════════════════════════════════════════
reload() {
    section "RELOAD $APP_NAME"
    log "PID file: $PID_FILE"

    is_running \
        || die "Not running — use start"

    local pid
    pid=$(get_pid)

    kill -USR1 "$pid" 2>/dev/null \
        || die "Failed to send USR1 to PID: $pid"

    success "USR1 sent to PID: $pid"
    success "Workers reopening log files in: $LOG_DIR"
}

# ════════════════════════════════════════════════════════════════
# STATUS
# ════════════════════════════════════════════════════════════════
status() {
    section "STATUS $APP_NAME"

    local port
    port=$(echo "${GUNICORN_BIND:-0.0.0.0:8001}" | cut -d: -f2)

    echo ""
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │                  Configuration                           │"
    echo "  ├────────────────────────────┬─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "App name"         "${APP_NAME:-unknown}"
    printf "  │  %-26s │ %s\n" "Running as"       "$(whoami)"
    printf "  │  %-26s │ %s\n" "Under systemd"    "$UNDER_SYSTEMD"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "PROJECT_ROOT"     "$PROJECT_ROOT"
    printf "  │  %-26s │ %s\n" "APP_DIR"          "$APP_DIR"
    printf "  │  %-26s │ %s\n" "VENV_DIR"         "$VENV_DIR"
    printf "  │  %-26s │ %s\n" "CONF_FILE"        "$CONF_FILE"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "LOG_DIR"          "$LOG_DIR"
    printf "  │  %-26s │ %s\n" "  access log"     "$LOG_DIR/gunicorn-access.log"
    printf "  │  %-26s │ %s\n" "  error log"      "$LOG_DIR/gunicorn-error.log"
    printf "  │  %-26s │ %s\n" "  app log"        "$LOG_DIR/app.log"
    echo "  ├────────────────────────────┼─────────────────────────────┤"
    printf "  │  %-26s │ %s\n" "RUN_DIR"          "$RUN_DIR"
    printf "  │  %-26s │ %s\n" "PID_FILE"         "$PID_FILE"
    printf "  │  %-26s │ %s\n" "ENV_FILE"         "${ENV_FILE:-NOT SET}"
    echo "  ├────────────────────────────┴─────────────────────────────┤"

    if is_running; then
        local pid workers uptime mem
        pid=$(get_pid)
        workers=$(get_worker_count "$pid")
        uptime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ' || echo "unknown")
        mem=$(ps -p "$pid" -o rss= 2>/dev/null \
            | awk '{printf "%.1f MB", $1/1024}' || echo "unknown")

        echo "  │                  Process Status                          │"
        echo "  ├────────────────────────────┬─────────────────────────────┤"
        printf "  │  %-26s │ %b\n" "Status"    "${GREEN}RUNNING${NC}"
        printf "  │  %-26s │ %s\n" "PID"       "$pid"
        printf "  │  %-26s │ %s\n" "Workers"   "$workers"
        printf "  │  %-26s │ %s\n" "Port"      "$port"
        printf "  │  %-26s │ %s\n" "Uptime"    "$uptime"
        printf "  │  %-26s │ %s\n" "Memory"    "$mem"

        # Symlink target
        if [ -L "$APP_DIR" ]; then
            local real_app
            real_app=$(readlink -f "$APP_DIR")
            printf "  │  %-26s │ %s\n" "Symlink target" "$real_app"
        fi

        # Release info
        if [ -f "$APP_DIR/.release_info" ]; then
            local ref commit deployed
            ref=$(grep      "^REF="          "$APP_DIR/.release_info" | cut -d= -f2)
            commit=$(grep   "^COMMIT_SHORT=" "$APP_DIR/.release_info" | cut -d= -f2)
            deployed=$(grep "^DEPLOYED_AT="  "$APP_DIR/.release_info" | cut -d= -f2)
            echo "  ├────────────────────────────┼─────────────────────────────┤"
            printf "  │  %-26s │ %s\n" "Branch/tag"  "$ref"
            printf "  │  %-26s │ %s\n" "Commit"      "$commit"
            printf "  │  %-26s │ %s\n" "Deployed at" "$deployed"
        fi

    else
        echo "  │                  Process Status                          │"
        echo "  ├────────────────────────────┬─────────────────────────────┤"
        printf "  │  %-26s │ %b\n" "Status" "${RED}STOPPED${NC}"
    fi

    echo "  └────────────────────────────┴─────────────────────────────┘"
    echo ""

    # Port check
    echo "  Port :$port"
    ss -tlnp 2>/dev/null | grep ":$port " \
        || echo "  Nothing listening on :$port"

    # Gunicorn processes
    echo ""
    echo "  Gunicorn processes:"
    pgrep -a -f "gunicorn: master" 2>/dev/null \
        | awk '{printf "    master pid=%s\n", $1}' \
        || echo "    none running"

    # Recent log lines
    echo ""
    echo "  Recent app log (last 5 lines):"
    if [ -f "$LOG_DIR/app.log" ]; then
        tail -5 "$LOG_DIR/app.log" \
            | awk '{printf "    %s\n", $0}'
    else
        echo "    $LOG_DIR/app.log not found yet"
    fi

    echo ""
    echo "  Recent access log (last 3 lines):"
    if [ -f "$LOG_DIR/gunicorn-access.log" ]; then
        tail -3 "$LOG_DIR/gunicorn-access.log" \
            | awk '{printf "    %s\n", $0}'
    else
        echo "    $LOG_DIR/gunicorn-access.log not found yet"
    fi
    echo ""
}

# ════════════════════════════════════════════════════════════════
# ENTRY POINT
# ════════════════════════════════════════════════════════════════

# Guard: command provided
COMMAND="${1:-}"

if [ -z "$COMMAND" ]; then
    echo ""
    echo "Usage: $0 {start|stop|restart|reload|status}"
    echo ""
    echo "Commands:"
    echo "  start   — start gunicorn (foreground if systemd, background if direct)"
    echo "  stop    — graceful stop via SIGTERM"
    echo "  restart — stop then start"
    echo "  reload  — USR1 — reopen log files (zero downtime)"
    echo "  status  — show process and configuration status"
    echo ""
    exit 1
fi

# ── Bootstrap: load vars + resolve paths for every command ────────
load_read_env
load_bootstrap_vars
ensure_app_user
resolve_paths

# ── Dispatch command ──────────────────────────────────────────────
case "$COMMAND" in
    start)
        validate_paths
        start
        ;;
    stop)
        stop
        ;;
    restart)
        validate_paths
        restart
        ;;
    reload)
        reload
        ;;
    status)
        status
        ;;
    *)
        error "Unknown command: $COMMAND"
        echo "Usage: $0 {start|stop|restart|reload|status}"
        exit 1
        ;;
esac