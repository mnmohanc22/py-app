#!/bin/bash
# /opt/scripts/bootstrap.sh
# Creates project root structure — all dirs under PROJECT_ROOT
# venv, configs, logs, run all inside PROJECT_ROOT
# Only envs dir lives outside
# Does NOT load .env — app1.sh responsibility
# Usage: ./bootstrap.sh [--vars /path/to/bootstrap.vars] [--force]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────
BOOTSTRAP_VARS="$(dirname "$0")/bootstrap.vars"
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

SCRIPTS_BASE="$(dirname "$0")"

# ════════════════════════════════════════════════════════════════
# STEP 1 — Load helpers
# ════════════════════════════════════════════════════════════════
log "Step 1: Loading helpers"

[ -f "$SCRIPTS_BASE/read_env.sh" ] \
    || die "read_env.sh not found: $SCRIPTS_BASE/read_env.sh"
source "$SCRIPTS_BASE/read_env.sh"
success "read_env.sh loaded"

[ -f "$SCRIPTS_BASE/create_dirs.sh" ] \
    || die "create_dirs.sh not found: $SCRIPTS_BASE/create_dirs.sh"
source "$SCRIPTS_BASE/create_dirs.sh"
success "create_dirs.sh loaded"

# ════════════════════════════════════════════════════════════════
# STEP 2 — Load bootstrap.vars
# ════════════════════════════════════════════════════════════════
log "Step 2: Loading vars from $BOOTSTRAP_VARS"

[ -f "$BOOTSTRAP_VARS" ] \
    || die "bootstrap.vars not found: $BOOTSTRAP_VARS"

load_env "$BOOTSTRAP_VARS"
success "Vars loaded from: $BOOTSTRAP_VARS"

# ════════════════════════════════════════════════════════════════
# STEP 3 — Validate bootstrap vars
# ════════════════════════════════════════════════════════════════
log "Step 3: Validating bootstrap vars"

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

[ ${#MISSING_VARS[@]} -eq 0 ] \
    || die "Fix bootstrap.vars — missing: ${MISSING_VARS[*]}"

# ════════════════════════════════════════════════════════════════
# STEP 4 — Resolve ALL paths from PROJECT_ROOT
# ════════════════════════════════════════════════════════════════
log "Step 4: Resolving all paths from PROJECT_ROOT=$PROJECT_ROOT"

# ── All resolved from PROJECT_ROOT ────────────────────────────────
APP_DIR="$PROJECT_ROOT/$APP_RELATIVE"
RELEASES_DIR="$PROJECT_ROOT/$RELEASES_RELATIVE"
CONFIGS_DIR="$PROJECT_ROOT/$CONFIGS_RELATIVE"
GUNICORN_CONF_DIR="$PROJECT_ROOT/$GUNICORN_CONF_RELATIVE"
LOG_DIR="$PROJECT_ROOT/$LOGS_RELATIVE"
RUN_DIR="$PROJECT_ROOT/$RUN_RELATIVE"
VENV_DIR="$PROJECT_ROOT/$VENV_RELATIVE"
PID_FILE="$RUN_DIR/$APP_NAME.pid"

# ── Requirements relative to APP_DIR ─────────────────────────────
if [[ "${REQUIREMENTS_FILE:-}" != /* ]]; then
    REQUIREMENTS_FILE="$APP_DIR/$REQUIREMENTS_FILE"
fi

# ── Export all resolved paths ─────────────────────────────────────
export APP_DIR RELEASES_DIR CONFIGS_DIR GUNICORN_CONF_DIR
export LOG_DIR RUN_DIR VENV_DIR PID_FILE REQUIREMENTS_FILE

# ── Print resolved paths ─────────────────────────────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │           Resolved Paths (all under PROJECT_ROOT)        │"
echo "  ├─────────────────────────────┬────────────────────────────┤"
printf "  │  %-27s │ %s\n" "PROJECT_ROOT"      "$PROJECT_ROOT"
echo "  ├─────────────────────────────┼────────────────────────────┤"
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
echo "  │  Outside project root       │                            │"
echo "  ├─────────────────────────────┼────────────────────────────┤"
printf "  │  %-27s │ %s\n" "ENVS_DIR"  "$ENVS_DIR"
printf "  │  %-27s │ %s\n" "ENV_FILE"  "$ENV_FILE"
echo "  └─────────────────────────────┴────────────────────────────┘"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 5 — Dir tree before creation
# ════════════════════════════════════════════════════════════════
log "Step 5: Directory status (before creation)"
print_dir_tree

# ════════════════════════════════════════════════════════════════
# STEP 6 — Create all directories
# ════════════════════════════════════════════════════════════════
log "Step 6: Creating project root and all directories"
create_project_dirs
success "All directories created"

# ════════════════════════════════════════════════════════════════
# STEP 7 — Dir tree after creation
# ════════════════════════════════════════════════════════════════
log "Step 7: Directory status (after creation)"
print_dir_tree

# ════════════════════════════════════════════════════════════════
# STEP 8 — Detect Python
# ════════════════════════════════════════════════════════════════
log "Step 8: Detecting Python >= $PYTHON_MIN_VERSION"

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
# STEP 9 — Create or reuse venv inside PROJECT_ROOT
# ════════════════════════════════════════════════════════════════
log "Step 9: Setting up venv at $VENV_DIR"

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
# STEP 10 — pip + requirements
# ════════════════════════════════════════════════════════════════
log "Step 10: Installing requirements from $REQUIREMENTS_FILE"

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
# STEP 11 — Verify key packages
# ════════════════════════════════════════════════════════════════
log "Step 11: Verifying key packages"

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