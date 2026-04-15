#!/bin/bash
# /opt/scripts/install_oracle_basiclite.sh
# Installs Oracle Instant Client 21.12 Basic Lite only on RHEL 8
# ZIP extraction to /opt/oracle
# Usage: ./install_oracle_basiclite.sh [--zip-dir /path/to/zips]

set -euo pipefail

# ════════════════════════════════════════════════════════════════
# CONFIG
# ════════════════════════════════════════════════════════════════
ORACLE_VERSION="21.12"
ORACLE_MAJOR="21"
ORACLE_FULL_VERSION="21.12.0.0.0"

# Install location
ORACLE_BASE="/opt/oracle"
ORACLE_HOME="/opt/oracle/instantclient_21_12"
TNS_ADMIN="/opt/oracle/network/admin"

# ZIP file location
ZIP_DIR="/tmp/oracle_zips"

# Basic Lite ZIP filename
ZIP_BASICLITE="instantclient-basiclite-linux.x64-${ORACLE_FULL_VERSION}dbru.zip"

# Download URL
DOWNLOAD_URL_BASE="https://download.oracle.com/otn_software/linux/instantclient/2112000"

# Ownership
INSTALL_USER="${SUDO_USER:-oracle}"
INSTALL_GROUP="oinstall"

# ════════════════════════════════════════════════════════════════
# PARSE ARGS
# ════════════════════════════════════════════════════════════════
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --zip-dir  <path>   Directory containing Oracle ZIP"
    echo "                      (default: /tmp/oracle_zips)"
    echo "  --user     <user>   Owner of install dir"
    echo "  --group    <group>  Group of install dir"
    echo "  --help              Show this help"
    echo ""
    echo "ZIP file expected:"
    echo "  $ZIP_BASICLITE"
    echo ""
    echo "Download from:"
    echo "  https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"
    echo "  Version 21.12 → Basic Light Package (ZIP)"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --zip-dir) ZIP_DIR="$2";       shift 2 ;;
        --user)    INSTALL_USER="$2";  shift 2 ;;
        --group)   INSTALL_GROUP="$2"; shift 2 ;;
        --help)    usage ;;
        *) echo "Unknown arg: $1"; usage ;;
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

log()     { echo -e "${BLUE}[oracle]${NC} $1"; }
success() { echo -e "${GREEN}[oracle] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[oracle] ⚠${NC} $1"; }
error()   { echo -e "${RED}[oracle] ✗${NC} $1"; }
die()     { error "$1"; exit 1; }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }

# ════════════════════════════════════════════════════════════════
# STEP 1 — Check root
# ════════════════════════════════════════════════════════════════
section "STEP 1: Check privileges"

[ "$(id -u)" = "0" ] \
    || die "Must run as root: sudo $0"

success "Running as root"

# ════════════════════════════════════════════════════════════════
# STEP 2 — Verify RHEL 8
# ════════════════════════════════════════════════════════════════
section "STEP 2: Verify RHEL 8"

[ -f /etc/redhat-release ] \
    || die "Not a RHEL system — /etc/redhat-release not found"

RHEL_FULL=$(cat /etc/redhat-release)
RHEL_MAJOR=$(rpm -q --queryformat '%{VERSION}' \
    redhat-release 2>/dev/null | cut -d. -f1)

success "OS: $RHEL_FULL"
success "RHEL major: $RHEL_MAJOR"

[ "$RHEL_MAJOR" = "8" ] \
    || warn "Expected RHEL 8 — got RHEL $RHEL_MAJOR — continuing"

ARCH=$(uname -m)
[ "$ARCH" = "x86_64" ] \
    || die "Only x86_64 supported — detected: $ARCH"

success "Architecture: $ARCH"

# ════════════════════════════════════════════════════════════════
# STEP 3 — Install prerequisites
# ════════════════════════════════════════════════════════════════
section "STEP 3: Install prerequisites"

PREREQS=(
    libaio      # async I/O — required by Oracle client
    libnsl      # network services library
    libnsl2     # network services library v2
    unzip       # extract Oracle ZIP
)

log "Installing via dnf"

for pkg in "${PREREQS[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        success "$pkg already installed"
    else
        dnf install -y "$pkg" > /dev/null 2>&1 \
            && success "$pkg installed" \
            || warn "$pkg not available — may not be required"
    fi
done

# ════════════════════════════════════════════════════════════════
# STEP 4 — Check existing installation
# ════════════════════════════════════════════════════════════════
section "STEP 4: Check existing installation"

if [ -d "$ORACLE_HOME" ]; then
    warn "Oracle Instant Client already exists: $ORACLE_HOME"
    echo ""
    ls "$ORACLE_HOME"/*.so* 2>/dev/null | head -5 \
        | awk '{printf "    %s\n", $0}' || true
    echo ""
    read -rp "  Reinstall? [y/N]: " REINSTALL
    if [[ "${REINSTALL:-N}" =~ ^[Yy]$ ]]; then
        log "Removing: $ORACLE_HOME"
        rm -rf "$ORACLE_HOME"
        success "Removed: $ORACLE_HOME"
    else
        log "Skipping — already installed"
        exit 0
    fi
fi

# ════════════════════════════════════════════════════════════════
# STEP 5 — Check ZIP file
# ════════════════════════════════════════════════════════════════
section "STEP 5: Check ZIP file"

mkdir -p "$ZIP_DIR"

ZIP_PATH="$ZIP_DIR/$ZIP_BASICLITE"

echo ""
printf "  %-20s %s\n" "ZIP dir:"       "$ZIP_DIR"
printf "  %-20s %s\n" "ZIP file:"      "$ZIP_BASICLITE"
printf "  %-20s %s\n" "Full path:"     "$ZIP_PATH"
echo ""

if [ -f "$ZIP_PATH" ]; then
    ZIP_SIZE=$(du -sh "$ZIP_PATH" | cut -f1)
    success "ZIP found: $ZIP_PATH ($ZIP_SIZE)"
else
    warn "ZIP not found: $ZIP_PATH"
    echo ""
    echo "  Manual download steps:"
    echo ""
    echo "  1. Open browser → go to:"
    echo "     https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"
    echo ""
    echo "  2. Select version 21.12"
    echo "     Download: Basic Light Package (ZIP)"
    echo "     File: $ZIP_BASICLITE"
    echo ""
    echo "  3. Copy ZIP to server:"
    echo "     scp $ZIP_BASICLITE root@server:$ZIP_DIR/"
    echo ""
    echo "  4. Re-run this script:"
    echo "     sudo $0 --zip-dir $ZIP_DIR"
    echo ""

    # Attempt download
    log "Attempting download (may fail — Oracle requires login)"
    if command -v wget &>/dev/null; then
        wget \
            --no-check-certificate \
            --tries=2 \
            --timeout=30 \
            --quiet \
            --show-progress \
            -O "$ZIP_PATH" \
            "$DOWNLOAD_URL_BASE/$ZIP_BASICLITE" 2>/dev/null \
            && success "Downloaded: $ZIP_BASICLITE" \
            || {
                rm -f "$ZIP_PATH" 2>/dev/null || true
                die "Download failed — place ZIP manually in $ZIP_DIR"
            }
    else
        die "wget not found and ZIP missing — place ZIP in $ZIP_DIR"
    fi
fi

# ════════════════════════════════════════════════════════════════
# STEP 6 — Verify ZIP integrity
# ════════════════════════════════════════════════════════════════
section "STEP 6: Verify ZIP integrity"

# Check not empty
ZIP_BYTES=$(stat -c%s "$ZIP_PATH" 2>/dev/null || echo 0)
[ "$ZIP_BYTES" -gt 1024 ] \
    || die "ZIP appears empty or corrupt: $ZIP_PATH ($ZIP_BYTES bytes)
    Re-download and try again"

# Test ZIP integrity
unzip -t "$ZIP_PATH" > /dev/null 2>&1 \
    || die "ZIP is corrupt: $ZIP_PATH
    Re-download from Oracle website"

# Show ZIP contents preview
echo ""
echo "  ZIP contents preview:"
unzip -l "$ZIP_PATH" 2>/dev/null \
    | head -15 \
    | awk '{printf "    %s\n", $0}'
echo ""

success "ZIP integrity OK: $ZIP_PATH"

# ════════════════════════════════════════════════════════════════
# STEP 7 — Create install directories
# ════════════════════════════════════════════════════════════════
section "STEP 7: Create directories"

# Create oracle base
mkdir -p "$ORACLE_BASE"
success "Created: $ORACLE_BASE"

# Create TNS admin
mkdir -p "$TNS_ADMIN"
success "Created: $TNS_ADMIN"

# Create group if not exists
if ! getent group "$INSTALL_GROUP" &>/dev/null; then
    groupadd -r "$INSTALL_GROUP"
    success "Group created: $INSTALL_GROUP"
else
    success "Group exists: $INSTALL_GROUP"
fi

# Create user if not exists
if ! getent passwd "$INSTALL_USER" &>/dev/null; then
    useradd -r \
        -g "$INSTALL_GROUP" \
        -d "$ORACLE_BASE" \
        -s /sbin/nologin \
        -c "Oracle Instant Client" \
        "$INSTALL_USER"
    success "User created: $INSTALL_USER"
else
    success "User exists: $INSTALL_USER"
fi

# ════════════════════════════════════════════════════════════════
# STEP 8 — Extract ZIP to /opt/oracle
# ════════════════════════════════════════════════════════════════
section "STEP 8: Extract ZIP to $ORACLE_BASE"

log "Extracting: $ZIP_BASICLITE → $ORACLE_BASE"

unzip -o \
    -q \
    "$ZIP_PATH" \
    -d "$ORACLE_BASE" \
    || die "Extraction failed: $ZIP_PATH"

# Verify ORACLE_HOME created
[ -d "$ORACLE_HOME" ] \
    || die "ORACLE_HOME not found after extraction: $ORACLE_HOME
    Expected: $ORACLE_BASE/instantclient_21_12
    ZIP may have different structure — check:
      unzip -l $ZIP_PATH | head -5"

success "Extracted to: $ORACLE_HOME"

echo ""
echo "  Extracted files:"
ls -lh "$ORACLE_HOME" \
    | awk '{printf "    %s\n", $0}'
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 9 — Create library symlinks
# ════════════════════════════════════════════════════════════════
section "STEP 9: Create library symlinks"

cd "$ORACLE_HOME"

# libclntsh symlink
LIBCLNTSH_VER=$(find "$ORACLE_HOME" \
    -name "libclntsh.so.*" \
    ! -name "*.dylib" \
    2>/dev/null | sort -V | tail -1)

if [ -n "$LIBCLNTSH_VER" ]; then
    ln -sf "$LIBCLNTSH_VER" "$ORACLE_HOME/libclntsh.so"
    success "libclntsh.so → $LIBCLNTSH_VER"
else
    warn "libclntsh.so.* not found in $ORACLE_HOME"
fi

# libclntshcore symlink
LIBCLNTSHCORE_VER=$(find "$ORACLE_HOME" \
    -name "libclntshcore.so.*" \
    2>/dev/null | sort -V | tail -1)

if [ -n "$LIBCLNTSHCORE_VER" ]; then
    ln -sf "$LIBCLNTSHCORE_VER" "$ORACLE_HOME/libclntshcore.so"
    success "libclntshcore.so → $LIBCLNTSHCORE_VER"
fi

# ════════════════════════════════════════════════════════════════
# STEP 10 — Set ownership and permissions
# ════════════════════════════════════════════════════════════════
section "STEP 10: Set ownership and permissions"

chown -R "$INSTALL_USER":"$INSTALL_GROUP" "$ORACLE_BASE"
chmod -R 755 "$ORACLE_HOME"
chmod -R 750 "$TNS_ADMIN"

success "Owner: $INSTALL_USER:$INSTALL_GROUP → $ORACLE_BASE"
success "Permissions: 755 → $ORACLE_HOME"

# ════════════════════════════════════════════════════════════════
# STEP 11 — Configure ldconfig
# ════════════════════════════════════════════════════════════════
section "STEP 11: Configure ldconfig"

LDCONF_FILE="/etc/ld.so.conf.d/oracle-instantclient.conf"

cat > "$LDCONF_FILE" << EOF
# Oracle Instant Client ${ORACLE_VERSION} Basic Lite
# Installed to: $ORACLE_HOME
$ORACLE_HOME
EOF

chmod 644 "$LDCONF_FILE"
ldconfig

success "ldconfig updated: $LDCONF_FILE"

# Verify
echo ""
echo "  Oracle libraries found by ldconfig:"
ldconfig -p | grep -i "libclntsh\|libocci\|libociicus" \
    | awk '{printf "    %s\n", $0}' \
    || warn "Libraries not found — check $LDCONF_FILE"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 12 — Set environment variables
# ════════════════════════════════════════════════════════════════
section "STEP 12: Set environment variables"

ENV_PROFILE="/etc/profile.d/oracle-instantclient.sh"

cat > "$ENV_PROFILE" << EOF
# Oracle Instant Client ${ORACLE_VERSION} Basic Lite
# Installed to: $ORACLE_HOME

export ORACLE_HOME=$ORACLE_HOME
export ORACLE_BASE=$ORACLE_BASE
export TNS_ADMIN=$TNS_ADMIN
export LD_LIBRARY_PATH=$ORACLE_HOME\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
EOF

chmod 644 "$ENV_PROFILE"

# shellcheck source=/dev/null
source "$ENV_PROFILE"

success "Environment profile: $ENV_PROFILE"

echo ""
printf "  %-25s = %s\n" "ORACLE_HOME"     "$ORACLE_HOME"
printf "  %-25s = %s\n" "ORACLE_BASE"     "$ORACLE_BASE"
printf "  %-25s = %s\n" "TNS_ADMIN"       "$TNS_ADMIN"
printf "  %-25s = %s\n" "LD_LIBRARY_PATH" "$ORACLE_HOME"
printf "  %-25s = %s\n" "NLS_LANG"        "AMERICAN_AMERICA.AL32UTF8"
echo ""

# ════════════════════════════════════════════════════════════════
# STEP 13 — Verify installation
# ════════════════════════════════════════════════════════════════
section "STEP 13: Verify installation"

echo ""
echo "  Key files in $ORACLE_HOME:"

for f in \
    "libclntsh.so" \
    "libclntshcore.so.21.1" \
    "libociicus.so" \
    "libnnz21.so"; do

    if [ -f "$ORACLE_HOME/$f" ] || [ -L "$ORACLE_HOME/$f" ]; then
        SIZE=$(du -sh "$ORACLE_HOME/$f" 2>/dev/null | cut -f1)
        success "$f ($SIZE)"
    else
        warn "$f not found"
    fi
done

echo ""
echo "  ldconfig check:"
ldconfig -p | grep libclntsh \
    && success "libclntsh found by dynamic linker" \
    || warn "libclntsh not in ldconfig"

# ════════════════════════════════════════════════════════════════
# DONE
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Oracle Instant Client ${ORACLE_VERSION} Basic Lite installed ✓  ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
printf "  %-25s %s\n" "Version:"      "$ORACLE_VERSION"
printf "  %-25s %s\n" "Type:"         "Basic Lite"
printf "  %-25s %s\n" "ORACLE_BASE:"  "$ORACLE_BASE"
printf "  %-25s %s\n" "ORACLE_HOME:"  "$ORACLE_HOME"
printf "  %-25s %s\n" "TNS_ADMIN:"    "$TNS_ADMIN"
printf "  %-25s %s\n" "Env profile:"  "$ENV_PROFILE"
printf "  %-25s %s\n" "ldconf:"       "$LDCONF_FILE"
printf "  %-25s %s\n" "Owner:"        "$INSTALL_USER:$INSTALL_GROUP"
echo ""
echo "  Directory layout:"
echo "    $ORACLE_BASE/"
echo "    ├── instantclient_21_12/     ← ORACLE_HOME"
echo "    │   ├── libclntsh.so         ← Oracle client library"
echo "    │   ├── libclntshcore.so.*"
echo "    │   └── libociicus.so"
echo "    └── network/admin/"
echo "        ├── tnsnames.ora"
echo "        └── sqlnet.ora"
echo ""
echo "  Next steps:"
echo "    1. Add DB connection : vi $TNS_ADMIN/tnsnames.ora"
echo "    2. Reload env        : source $ENV_PROFILE"
echo "    3. Install Python    : pip install python-oracledb"
echo "    4. Test Python:"
echo "       python3 -c \""
echo "       import oracledb"
echo "       oracledb.init_oracle_client(lib_dir='$ORACLE_HOME')"
echo "       print('Oracle client OK')\""
echo ""

# ── Cleanup ───────────────────────────────────────────────────────
read -rp "  Remove ZIP from $ZIP_DIR? [y/N]: " CLEANUP
if [[ "${CLEANUP:-N}" =~ ^[Yy]$ ]]; then
    rm -f "$ZIP_PATH"
    success "Removed: $ZIP_PATH"
fi