# wsgi.py
# Gunicorn entry point — imports Flask app and exposes it
# as 'application' callable

import os
from pathlib import Path
from dotenv import load_dotenv

# ── Load .env if it exists ────────────────────────────────────
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    load_dotenv(dotenv_path=str(env_path))
else:
    print("[wsgi] .env not found — using defaults")

# ── Ensure log directory exists ───────────────────────────────
log_dir = os.environ.get('LOG_DIR', '/tmp/simple-flask/logs')
os.makedirs(log_dir, exist_ok=True)

# ── Import Flask app from app.py ──────────────────────────────
from app import app as application

# ── Direct run fallback — python3 wsgi.py ────────────────────
if __name__ == '__main__':
    application.run(host='0.0.0.0', port=5000, debug=False)