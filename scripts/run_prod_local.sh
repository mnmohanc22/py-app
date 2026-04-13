#!/bin/bash
# scripts/run_prod_local.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "======================================="
echo " py-app — Production Local Startup"
echo "======================================="
echo "Project root : $PROJECT_ROOT"

# ── Step 1: Check venv ────────────────────────────────────────
if [ ! -f "venv/bin/activate" ]; then
    echo "Creating venv..."
    python3 -m venv venv
    venv/bin/pip install --upgrade pip setuptools wheel -q
    venv/bin/pip install -r requirements.txt -q
    echo "venv created and dependencies installed"
fi

source venv/bin/activate
echo "venv         : active"

# ── Step 2: Check .env ───────────────────────────────────────
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo ".env         : created from .env.example"
        echo "WARNING      : update .env values before production use"
    else
        echo "ERROR        : .env not found and .env.example missing"
        echo ""
        echo "Create .env manually:"
        echo "  cat > .env << 'EOF'"
        echo "  FLASK_ENV=production"
        echo "  SECRET_KEY=change-me"
        echo "  LOG_DIR=/tmp/py-app/logs"
        echo "  EOF"
        exit 1
    fi
else
    echo ".env         : found"
fi

# Load .env
export $(grep -v '^#' .env | xargs)
echo "FLASK_ENV    : $FLASK_ENV"

# ── Step 3: Create directories ───────────────────────────────
LOG_DIR="${LOG_DIR:-/tmp/py-app/logs}"
mkdir -p "$LOG_DIR"
mkdir -p "/tmp/py-app"
echo "Log dir      : $LOG_DIR"

# ── Step 4: Check port is free ───────────────────────────────
PORT=8000
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "ERROR        : Port $PORT already in use"
    echo "Run: lsof -i :$PORT to see what is using it"
    exit 1
fi
echo "Port         : $PORT (free)"

# ── Step 5: Start gunicorn ───────────────────────────────────
echo "======================================="
echo " Starting gunicorn..."
echo "======================================="

venv/bin/gunicorn \
    --config gunicorn.local.conf.py \
    wsgi:application