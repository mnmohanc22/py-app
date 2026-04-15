#!/bin/bash
# /opt/scripts/create_venv.sh
# Creates virtualenv and installs requirements from APP_DIR
# Reads all paths from bootstrap.vars
# Usage: ./create_venv.sh [--vars bootstrap.vars] [--force]

set -euo pipefail

# ════════════════════════════════════════════════════════════════
# DEFAULTS
# ════════════════════════════════════════════════════════════════
BOOTSTRAP_VARS=""
FORCE_RECREATE=false

# ════════════════════════════════════════════════════════════════
# PARSE ARGS
# ════════════════════════════════════════════════════════════════
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --vars  <path>   Path to bootstrap.vars (default: ./bootstrap.vars)"
    echo "  --force          Force recreate venv even if it exists"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --vars /opt/scripts/bootstrap.vars"
    echo "  $0 --force"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vars)  BOOTSTRAP_VARS="$2"; shift 2 ;;
        --force) FORCE_RECREATE=true; shift ;;
        --help)  usage ;;
        *)
            echo "Unknown arg: $1"
            usage
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
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[create_venv]${NC} $1"; }
success() { echo -e "${GREEN}[create_venv] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[create_venv] ⚠${NC} $1"; }
error()   { echo -e "${RED}[create_venv] ✗${NC} $1"; }
die()     { error "$1"; exit 1; }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }

# ════════════════════════════════════════════════════════════════
# RESOLVE SCRIPTS BASE DIR
# ════════════════════════════════════════════════════════════════
if command -v realpath &>/dev/null; then
    SCRIPTS_BASE="$(dirname "$(realpath "$0")")"
else
    SCRIPTS_BASE="$(cd "$(dirname "$0")" && pwd)"
fi

log "Scripts base: $SCRIPTS_BASE"

# ── Set default bootstrap.vars ────────────────────────────────────
if [ -z "$BOOTSTRAP_VARS" ]; then
    BOOTSTRAP_VARS="$SCRIPTS_BASE/bootstrap.vars"
fi

log "Bootstrap vars: $BOOTSTRAP_VARS"

# ════════════════════════════════════════════════════════════════
# STEP 1 — Source read_env.sh
# ════════════════════════════════════════════════════════════════
section "STEP 1: Source read_env.sh"

READ_ENV="$SCRIPTS_BASE/read_env.sh"

# Guard: exists
[ -f "$READ_ENV" ] \
    || die "read_env.sh not found: $READ_ENV"

# Guard: readable
[ -r "$READ_ENV" ] \
    || die "read_env.sh not readable: $READ_ENV
    Fix: chmod 644 $READ_ENV"

# Fix CRLF
if file "$READ_ENV" | grep -q "CRLF"; then
    warn "CRLF detected in read_env.sh — fixing"
    sed -i 's/\r//' "$READ_ENV"
fi

# shellcheck source=/dev/null
source "$READ_ENV"

# Guard: function available
declare -f load_env > /dev/null 2>&1 \
    || die "load_env not found after sourcing $READ_ENV
    Check read_env.sh defines load_env()"

success "read_env.sh sourced — load_env available"

# ════════════════════════════════════════════════════════════════
# STEP 2 — Load bootstrap.vars
# ════════════════════════════════════════════════════════════════
section "STEP 2: Load bootstrap.vars"

[ -f "$BOOTSTRAP_VARS" ] \
    || die "bootstrap.vars not found: $BOOTSTRAP_VARS"

[ -r "$BOOTSTRAP_VARS" ] \
    || die "bootstrap.vars not readable: $BOOTSTRAP_VARS"

# Fix CRLF
if file "$BOOTSTRAP_VARS" | grep -q "CRLF"; then
    warn "CRLF detected in bootstrap.vars — fixing"
    sed -i 's/\r//' "$BOOTSTRAP_VARS"
fi

load_env "$BOOTSTRAP_VARS"
success "bootstrap.vars loaded"

# ════════════════════════════════════════════════════════════════
# STEP 3 — Validate required vars
# ════════════════════════════════════════════════════════════════
section "STEP 3: Validate required vars"

REQUIRED_VARS=(
    PROJECT_ROOT
    APP_RELATIVE
    VENV_RELATIVE
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
# STEP 4 — Resolve paths from PROJECT_ROOT
# ════════════════════════════════════════════════════════════════
section "STEP 4: Resolve paths from PROJECT_ROOT"

# App dir — source code
APP_DIR="$PROJECT_ROOT/$APP_RELATIVE"

# Venv dir — inside project root
VENV_DIR="$PROJECT_ROOT/$VENV_RELATIVE"

# Requirements file — relative to APP_DIR if not absolute
if [[ "${REQUIREMENTS_FILE:-}" != /* ]]; then
    REQUIREMENTS_FILE="$APP_DIR/$REQUIREMENTS_FILE"
fi

echo ""
printf "  %-25s %s\n" "PROJECT_ROOT:"     "$PROJECT_ROOT"
printf "  %-25s %s\n" "APP_DIR:"          "$APP_DIR"
printf "  %-25s %s\n" "VENV_DIR:"         "$VENV_DIR"
printf "  %-25s %s\n" "REQUIREMENTS_FILE:" "$REQUIREMENTS_FILE"
printf "  %-25s %s\n" "PYTHON_MIN_VERSION:" "$PYTHON_MIN_VERSION"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 5 — Validate APP_DIR and requirements.txt
# ════════════════════════════════════════════════════════════════
section "STEP 5: Validate APP_DIR and requirements.txt"

# APP_DIR must exist
[ -d "$APP_DIR" ] \
    || die "APP_DIR not found: $APP_DIR
    Run deploy.sh first to checkout source code"

success "APP_DIR exists: $APP_DIR"

# Show what is checked out in APP_DIR
if git -C "$APP_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$APP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    COMMIT=$(git -C "$APP_DIR" rev-parse --short HEAD  2>/dev/null || echo "unknown")
    TAG=$(git -C "$APP_DIR" describe --tags --exact-match 2>/dev/null || echo "no tag")
    success "Source: branch=$BRANCH | commit=$COMMIT | tag=$TAG"
fi

# requirements.txt must exist in APP_DIR
[ -f "$REQUIREMENTS_FILE" ] \
    || die "requirements.txt not found: $REQUIREMENTS_FILE
    Expected at: $APP_DIR/requirements.txt"

# Show requirements count
REQ_COUNT=$(grep -cve '^\s*#' "$REQUIREMENTS_FILE" 2>/dev/null || echo 0)
REQ_COMMENT=$(grep -ce '^\s*#' "$REQUIREMENTS_FILE" 2>/dev/null || echo 0)
success "requirements.txt found: $REQUIREMENTS_FILE"
log "  Packages  : $REQ_COUNT"
log "  Comments  : $REQ_COMMENT"

echo ""
echo "  Requirements preview:"
grep -ve '^\s*#' "$REQUIREMENTS_FILE" \
    | grep -ve '^\s*$' \
    | head -10 \
    | awk '{printf "    %s\n", $0}'
[ "$REQ_COUNT" -gt 10 ] && echo "    ... ($((REQ_COUNT - 10)) more)"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 6 — Detect Python binary
# ════════════════════════════════════════════════════════════════
section "STEP 6: Detect Python >= $PYTHON_MIN_VERSION"

PYTHON_BIN=""
MIN_MAJOR=$(echo "$PYTHON_MIN_VERSION" | cut -d. -f1)
MIN_MINOR=$(echo "$PYTHON_MIN_VERSION" | cut -d. -f2)

for bin in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$bin" &>/dev/null; then
        PY_VER=$("$bin" -c \
            "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" \
            2>/dev/null || echo "0.0")

        MAJOR=$(echo "$PY_VER" | cut -d. -f1)
        MINOR=$(echo "$PY_VER" | cut -d. -f2)

        if [ "$MAJOR" -gt "$MIN_MAJOR" ] || \
           ([ "$MAJOR" -eq "$MIN_MAJOR" ] && [ "$MINOR" -ge "$MIN_MINOR" ]); then
            PYTHON_BIN=$(command -v "$bin")
            success "Found: $PYTHON_BIN ($PY_VER)"
            break
        else
            warn "$bin ($PY_VER) < required $PYTHON_MIN_VERSION — skipping"
        fi
    fi
done

[ -n "$PYTHON_BIN" ] \
    || die "No Python >= $PYTHON_MIN_VERSION found.
    Install: sudo dnf install python3.11 -y"

# ════════════════════════════════════════════════════════════════
# STEP 7 — Create or reuse venv
# ════════════════════════════════════════════════════════════════
section "STEP 7: Setup venv at $VENV_DIR"

# Force recreate
if $FORCE_RECREATE && [ -d "$VENV_DIR" ]; then
    warn "--force: removing existing venv at $VENV_DIR"
    rm -rf "$VENV_DIR"
    success "Old venv removed"
fi

# Check existing venv health
if [ -d "$VENV_DIR" ]; then

    # Check python binary exists in venv
    if [ ! -f "$VENV_DIR/bin/python" ]; then
        warn "Venv missing python binary — recreating"
        rm -rf "$VENV_DIR"

    # Check venv python version
    else
        VENV_PY_VER=$("$VENV_DIR/bin/python" -c \
            "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" \
            2>/dev/null || echo "0.0")

        VENV_MAJOR=$(echo "$VENV_PY_VER" | cut -d. -f1)
        VENV_MINOR=$(echo "$VENV_PY_VER" | cut -d. -f2)

        if [ "$VENV_PY_VER" = "0.0" ]; then
            warn "Venv appears broken — recreating"
            rm -rf "$VENV_DIR"

        elif [ "$VENV_MAJOR" -lt "$MIN_MAJOR" ] || \
             ([ "$VENV_MAJOR" -eq "$MIN_MAJOR" ] && \
              [ "$VENV_MINOR" -lt "$MIN_MINOR" ]); then
            warn "Venv Python $VENV_PY_VER < required $PYTHON_MIN_VERSION — recreating"
            rm -rf "$VENV_DIR"

        else
            success "Existing venv OK: $VENV_DIR (Python $VENV_PY_VER)"
        fi
    fi
fi

# Create venv if not present
if [ ! -d "$VENV_DIR" ]; then
    log "Creating venv: $PYTHON_BIN -m venv $VENV_DIR"

    $PYTHON_BIN -m venv "$VENV_DIR" \
        || die "venv creation failed at $VENV_DIR"

    success "Venv created: $VENV_DIR"
    log "Python : $($VENV_DIR/bin/python --version)"
fi

# Verify venv structure
for f in bin/python bin/pip bin/activate; do
    [ -f "$VENV_DIR/$f" ] \
        && success "venv/$f exists" \
        || die "venv/$f missing — venv may be corrupt. Run --force"
done

# ════════════════════════════════════════════════════════════════
# STEP 8 — Upgrade pip in venv
# ════════════════════════════════════════════════════════════════
section "STEP 8: Upgrade pip"

PIP="$VENV_DIR/bin/pip"

"$PIP" install \
    --upgrade pip \
    --quiet \
    || die "pip upgrade failed"

PIP_VER=$("$PIP" --version | awk '{print $2}')
success "pip: $PIP_VER"

# ════════════════════════════════════════════════════════════════
# STEP 9 — Install requirements from APP_DIR
# ════════════════════════════════════════════════════════════════
section "STEP 9: Install requirements from $REQUIREMENTS_FILE"

log "Installing $REQ_COUNT packages..."

"$PIP" install \
    -r "$REQUIREMENTS_FILE" \
    --quiet \
    --no-warn-script-location \
    || die "pip install -r $REQUIREMENTS_FILE failed
    Check: $REQUIREMENTS_FILE
    Try  : $PIP install -r $REQUIREMENTS_FILE (without --quiet for details)"

success "Requirements installed from: $REQUIREMENTS_FILE"

# ════════════════════════════════════════════════════════════════
# STEP 10 — Verify installed packages
# ════════════════════════════════════════════════════════════════
section "STEP 10: Verify installed packages"

# Verify every non-comment line in requirements.txt is installed
FAILED_PKG=()
PASSED_PKG=()

while IFS= read -r req || [ -n "$req" ]; do

    # Skip blank and comment lines
    [[ -z "$req" || "$req" =~ ^[[:space:]]*# ]] && continue

    # Strip version specifier to get package name
    # e.g. flask>=3.0.0 → flask
    PKG_NAME=$(echo "$req" \
        | sed 's/[>=<!;].*//' \
        | sed 's/\[.*//' \
        | tr -d ' ' \
        | tr '[:upper:]' '[:lower:]')

    [ -z "$PKG_NAME" ] && continue

    PKG_VER=$("$PIP" show "$PKG_NAME" 2>/dev/null \
        | grep "^Version:" \
        | awk '{print $2}')

    if [ -n "$PKG_VER" ]; then
        success "$PKG_NAME == $PKG_VER"
        PASSED_PKG+=("$PKG_NAME")
    else
        error "$PKG_NAME NOT installed"
        FAILED_PKG+=("$PKG_NAME")
    fi

done < "$REQUIREMENTS_FILE"

# Summary
echo ""
log "Verification summary:"
log "  Passed : ${#PASSED_PKG[@]} packages"
log "  Failed : ${#FAILED_PKG[@]} packages"

[ ${#FAILED_PKG[@]} -eq 0 ] \
    || die "Missing packages: ${FAILED_PKG[*]}
    Try: $PIP install -r $REQUIREMENTS_FILE"

# ════════════════════════════════════════════════════════════════
# DONE
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  create_venv complete ✓                               ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
printf "  %-25s %s\n" "Project root:"    "$PROJECT_ROOT"
printf "  %-25s %s\n" "App dir:"         "$APP_DIR"
printf "  %-25s %s\n" "Venv:"            "$VENV_DIR"
printf "  %-25s %s\n" "Python:"          "$($VENV_DIR/bin/python --version)"
printf "  %-25s %s\n" "Pip:"             "$($PIP --version | awk '{print $2}')"
printf "  %-25s %s\n" "Requirements:"    "$REQUIREMENTS_FILE"
printf "  %-25s %s\n" "Packages:"        "$REQ_COUNT installed"
echo ""
echo "  Installed packages:"
"$PIP" list --format=columns 2>/dev/null \
    | grep -iE "^(Flask|gunicorn|SQLAlchemy|python-dotenv|psycopg2|Werkzeug|flask)" \
    | awk '{printf "    %-30s %s\n", $1, $2}'
echo ""
echo "  Next:"
echo "    Start app : $SCRIPTS_DIR/app1.sh start"
echo ""