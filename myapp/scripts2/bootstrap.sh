#!/bin/bash
# /opt/scripts/bootstrap.sh

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────
BOOTSTRAP_VARS=""
FORCE_RECREATE=false

# ── Parse args ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --vars)  BOOTSTRAP_VARS="$2"; shift 2 ;;
        --force) FORCE_RECREATE=true; shift ;;
        *)
            echo "Usage: $0 [--vars /path/to/bootstrap.vars] [--force]"
            exit 1
            ;;
    esac
done

# ════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[bootstrap]${NC} $1"; }
success() { echo -e "${GREEN}[bootstrap] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[bootstrap] ⚠${NC} $1"; }
error()   { echo -e "${RED}[bootstrap] ✗${NC} $1"; }
die()     { error "$1"; exit 1; }

# ════════════════════════════════════════════════════════════════
# RESOLVE SCRIPTS DIRECTORY — must come before anything else
# ════════════════════════════════════════════════════════════════

# realpath resolves symlinks — works wherever script is called from
if command -v realpath &>/dev/null; then
    SCRIPTS_BASE="$(dirname "$(realpath "$0")")"
else
    # Fallback for systems without realpath
    SCRIPTS_BASE="$(cd "$(dirname "$0")" && pwd)"
fi

log "Scripts base dir: $SCRIPTS_BASE"

# ── Set default bootstrap.vars if not provided ────────────────────
if [ -z "$BOOTSTRAP_VARS" ]; then
    BOOTSTRAP_VARS="$SCRIPTS_BASE/bootstrap.vars"
fi

log "Bootstrap vars: $BOOTSTRAP_VARS"

# ════════════════════════════════════════════════════════════════
# STEP 1 — Source read_env.sh and verify load_env function
# ════════════════════════════════════════════════════════════════
log "Step 1: Loading read_env.sh"

READ_ENV_PATH="$SCRIPTS_BASE/read_env.sh"

# Guard: read_env.sh exists
if [ ! -f "$READ_ENV_PATH" ]; then
    die "read_env.sh not found: $READ_ENV_PATH
    Expected at: $SCRIPTS_BASE/read_env.sh
    Fix: make sure read_env.sh is in the same directory as bootstrap.sh"
fi

# Guard: read_env.sh readable
if [ ! -r "$READ_ENV_PATH" ]; then
    die "read_env.sh not readable: $READ_ENV_PATH
    Fix: chmod 644 $READ_ENV_PATH"
fi

# Guard: check for Windows line endings
if file "$READ_ENV_PATH" | grep -q "CRLF"; then
    warn "Windows line endings detected in read_env.sh — fixing"
    sed -i 's/\r//' "$READ_ENV_PATH" \
        && success "Line endings fixed" \
        || die "Failed to fix line endings — run: sed -i 's/\r//' $READ_ENV_PATH"
fi

# Source read_env.sh
# shellcheck source=/dev/null
source "$READ_ENV_PATH"

# Guard: verify load_env function is now available
if ! declare -f load_env > /dev/null 2>&1; then
    die "load_env function not found after sourcing $READ_ENV_PATH
    Check read_env.sh contains: load_env() { ... }
    Debug: grep -n 'load_env' $READ_ENV_PATH"
fi

success "read_env.sh sourced — load_env is available"

# ════════════════════════════════════════════════════════════════
# STEP 2 — Source create_dirs.sh and verify function
# ════════════════════════════════════════════════════════════════
log "Step 2: Loading create_dirs.sh"

CREATE_DIRS_PATH="$SCRIPTS_BASE/create_dirs.sh"

if [ ! -f "$CREATE_DIRS_PATH" ]; then
    die "create_dirs.sh not found: $CREATE_DIRS_PATH"
fi

if [ ! -r "$CREATE_DIRS_PATH" ]; then
    die "create_dirs.sh not readable: $CREATE_DIRS_PATH
    Fix: chmod 644 $CREATE_DIRS_PATH"
fi

# Fix CRLF if needed
if file "$CREATE_DIRS_PATH" | grep -q "CRLF"; then
    warn "Windows line endings in create_dirs.sh — fixing"
    sed -i 's/\r//' "$CREATE_DIRS_PATH"
fi

source "$CREATE_DIRS_PATH"

if ! declare -f create_project_dirs > /dev/null 2>&1; then
    die "create_project_dirs function not found after sourcing $CREATE_DIRS_PATH"
fi

success "create_dirs.sh sourced — create_project_dirs is available"

# ════════════════════════════════════════════════════════════════
# STEP 3 — Load bootstrap.vars
# ════════════════════════════════════════════════════════════════
log "Step 3: Loading bootstrap.vars"

if [ ! -f "$BOOTSTRAP_VARS" ]; then
    die "bootstrap.vars not found: $BOOTSTRAP_VARS
    Create it at: $SCRIPTS_BASE/bootstrap.vars"
fi

if [ ! -r "$BOOTSTRAP_VARS" ]; then
    die "bootstrap.vars not readable: $BOOTSTRAP_VARS"
fi

# Fix CRLF if needed
if file "$BOOTSTRAP_VARS" | grep -q "CRLF"; then
    warn "Windows line endings in bootstrap.vars — fixing"
    sed -i 's/\r//' "$BOOTSTRAP_VARS"
fi

# Now call load_env — function is verified available
load_env "$BOOTSTRAP_VARS"

success "bootstrap.vars loaded"

# ════════════════════════════════════════════════════════════════
# STEP 4 — Validate required vars
# ════════════════════════════════════════════════════════════════
log "Step 4: Validating bootstrap vars"

REQUIRED_VARS=(
    APP_NAME
    APP_USER
    APP_GROUP
    PROJECT_ROOT
    APP_RELATIVE
    RELEASES_RELATIVE
    CONFIGS_RELATIVE
    GUNICORN_CONF_RELATIVE
    LOGS_RELATIVE
    RUN_RELATIVE
    VENV_RELATIVE
    ENVS_DIR
    ENV_FILE
    SCRIPTS_DIR
    REQUIREMENTS_FILE
    PYTHON_MIN_VERSION
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    value="${!var:-}"
    if [ -z "$value" ]; then
        error "Not set in bootstrap.vars: $var"
        MISSING_VARS+=("$var")
    else
        success "$var = $value"
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    die "Fix bootstrap.vars — missing vars: ${MISSING_VARS[*]}"
fi

# ════════════════════════════════════════════════════════════════
# STEP 5 — Resolve paths from PROJECT_ROOT
# ════════════════════════════════════════════════════════════════
log "Step 5: Resolving paths from PROJECT_ROOT=$PROJECT_ROOT"

APP_DIR="$PROJECT_ROOT/$APP_RELATIVE"
RELEASES_DIR="$PROJECT_ROOT/$RELEASES_RELATIVE"
CONFIGS_DIR="$PROJECT_ROOT/$CONFIGS_RELATIVE"
GUNICORN_CONF_DIR="$PROJECT_ROOT/$GUNICORN_CONF_RELATIVE"
LOG_DIR="$PROJECT_ROOT/$LOGS_RELATIVE"
RUN_DIR="$PROJECT_ROOT/$RUN_RELATIVE"
VENV_DIR="$PROJECT_ROOT/$VENV_RELATIVE"
PID_FILE="$RUN_DIR/$APP_NAME.pid"

if [[ "${REQUIREMENTS_FILE:-}" != /* ]]; then
    REQUIREMENTS_FILE="$APP_DIR/$REQUIREMENTS_FILE"
fi

export APP_DIR RELEASES_DIR CONFIGS_DIR GUNICORN_CONF_DIR
export LOG_DIR RUN_DIR VENV_DIR PID_FILE REQUIREMENTS_FILE

echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │           Resolved Paths                                 │"
echo "  ├─────────────────────────────┬────────────────────────────┤"
printf "  │  %-27s │ %s\n" "PROJECT_ROOT"      "$PROJECT_ROOT"
printf "  │  %-27s │ %s\n" "APP_DIR"           "$APP_DIR"
printf "  │  %-27s │ %s\n" "RELEASES_DIR"      "$RELEASES_DIR"
printf "  │  %-27s │ %s\n" "CONFIGS_DIR"       "$CONFIGS_DIR"
printf "  │  %-27s │ %s\n" "GUNICORN_CONF_DIR" "$GUNICORN_CONF_DIR"
printf "  │  %-27s │ %s\n" "LOG_DIR"           "$LOG_DIR"
printf "  │  %-27s │ %s\n" "RUN_DIR"           "$RUN_DIR"
printf "  │  %-27s │ %s\n" "VENV_DIR"          "$VENV_DIR"
printf "  │  %-27s │ %s\n" "PID_FILE"          "$PID_FILE"
printf "  │  %-27s │ %s\n" "REQUIREMENTS_FILE" "$REQUIREMENTS_FILE"
echo "  ├─────────────────────────────┼────────────────────────────┤"
printf "  │  %-27s │ %s\n" "ENVS_DIR"  "$ENVS_DIR"
printf "  │  %-27s │ %s\n" "ENV_FILE"  "$ENV_FILE"
echo "  └─────────────────────────────┴────────────────────────────┘"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 6 — Dir tree before creation
# ════════════════════════════════════════════════════════════════
log "Step 6: Directory status (before creation)"
print_dir_tree

# ════════════════════════════════════════════════════════════════
# STEP 7 — Create directories
# ════════════════════════════════════════════════════════════════
log "Step 7: Creating directories"
create_project_dirs
success "All directories created"

# ════════════════════════════════════════════════════════════════
# STEP 8 — Dir tree after creation
# ════════════════════════════════════════════════════════════════
log "Step 8: Directory status (after creation)"
print_dir_tree

# ════════════════════════════════════════════════════════════════
# STEP 9 — Detect Python
# ════════════════════════════════════════════════════════════════
log "Step 9: Detecting Python >= $PYTHON_MIN_VERSION"

PYTHON_BIN=""
MIN_MAJOR=$(echo "$PYTHON_MIN_VERSION" | cut -d. -f1)
MIN_MINOR=$(echo "$PYTHON_MIN_VERSION" | cut -d. -f2)

for bin in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$bin" &>/dev/null; then
        PY_VER=$("$bin" -c \
            "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        MAJOR=$(echo "$PY_VER" | cut -d. -f1)
        MINOR=$(echo "$PY_VER" | cut -d. -f2)

        if [ "$MAJOR" -gt "$MIN_MAJOR" ] || \
           ([ "$MAJOR" -eq "$MIN_MAJOR" ] && [ "$MINOR" -ge "$MIN_MINOR" ]); then
            PYTHON_BIN="$bin"
            success "Python: $PYTHON_BIN ($PY_VER)"
            break
        else
            warn "$bin ($PY_VER) < $PYTHON_MIN_VERSION — skipping"
        fi
    fi
done

[ -n "$PYTHON_BIN" ] \
    || die "Python >= $PYTHON_MIN_VERSION not found.
    Install: sudo dnf install python3.11 -y"

# ════════════════════════════════════════════════════════════════
# STEP 10 — Create or reuse venv
# ════════════════════════════════════════════════════════════════
log "Step 10: Setting up venv at $VENV_DIR"

if $FORCE_RECREATE && [ -d "$VENV_DIR" ]; then
    warn "--force: removing $VENV_DIR"
    rm -rf "$VENV_DIR"
fi

if [ -d "$VENV_DIR" ]; then
    VENV_PY_VER=$("$VENV_DIR/bin/python" -c \
        "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" \
        2>/dev/null || echo "0.0")

    if [ "$VENV_PY_VER" = "0.0" ]; then
        warn "Venv broken — recreating"
        rm -rf "$VENV_DIR"
    else
        success "Venv OK: $VENV_DIR (Python $VENV_PY_VER)"
    fi
fi

if [ ! -d "$VENV_DIR" ]; then
    log "Creating: $PYTHON_BIN -m venv $VENV_DIR"
    $PYTHON_BIN -m venv "$VENV_DIR" \
        || die "venv creation failed: $VENV_DIR"
    success "Venv created: $VENV_DIR"
fi

# ════════════════════════════════════════════════════════════════
# STEP 11 — pip + requirements
# ════════════════════════════════════════════════════════════════
log "Step 11: Installing requirements from $REQUIREMENTS_FILE"

[ -f "$REQUIREMENTS_FILE" ] \
    || die "requirements.txt not found: $REQUIREMENTS_FILE"

"$VENV_DIR/bin/pip" install --upgrade pip --quiet \
    || die "pip upgrade failed"

success "pip: $("$VENV_DIR/bin/pip" --version | awk '{print $2}')"

REQ_COUNT=$(grep -cve '^\s*#' "$REQUIREMENTS_FILE" 2>/dev/null || echo 0)
log "Installing $REQ_COUNT packages"

"$VENV_DIR/bin/pip" install \
    -r "$REQUIREMENTS_FILE" \
    --quiet \
    --no-warn-script-location \
    || die "pip install failed"

success "Requirements installed"

# ════════════════════════════════════════════════════════════════
# STEP 12 — Verify packages
# ════════════════════════════════════════════════════════════════
log "Step 12: Verifying key packages"

REQUIRED_PACKAGES=(flask gunicorn python-dotenv flask-sqlalchemy)
FAILED_PACKAGES=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    PKG_VER=$("$VENV_DIR/bin/pip" show "$pkg" 2>/dev/null \
        | grep "^Version:" | awk '{print $2}')
    if [ -n "$PKG_VER" ]; then
        success "$pkg == $PKG_VER"
    else
        error "$pkg NOT installed"
        FAILED_PACKAGES+=("$pkg")
    fi
done

[ ${#FAILED_PACKAGES[@]} -eq 0 ] \
    || die "Missing packages: ${FAILED_PACKAGES[*]}"

# ════════════════════════════════════════════════════════════════
# DONE
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Bootstrap complete ✓                                 ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
printf "  %-22s %s\n" "App:"          "$APP_NAME"
printf "  %-22s %s\n" "Project root:" "$PROJECT_ROOT"
printf "  %-22s %s\n" "App dir:"      "$APP_DIR"
printf "  %-22s %s\n" "Releases:"     "$RELEASES_DIR"
printf "  %-22s %s\n" "Configs:"      "$CONFIGS_DIR"
printf "  %-22s %s\n" "Logs:"         "$LOG_DIR"
printf "  %-22s %s\n" "Run:"          "$RUN_DIR"
printf "  %-22s %s\n" "Venv:"         "$VENV_DIR"
printf "  %-22s %s\n" "Port:"         "$APP_PORT"
printf "  %-22s %s\n" "User:"         "$APP_USER:$APP_GROUP"
echo ""
echo "  Note: .env not loaded here — app1.sh loads at startup"
echo ""
echo "  Next:"
echo "    Place .env  : cp $APP_DIR/.env.example $ENV_FILE"
echo "    Edit .env   : vi $ENV_FILE"
echo "    Start app   : $SCRIPTS_DIR/app1.sh start"
echo ""