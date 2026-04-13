# wsgi.py — gunicorn entry point

import os
import sys
from dotenv import load_dotenv

# ── Load environment variables from .env ──────────────────────
# Must happen BEFORE importing Flask app
# so config.py reads correct os.environ values
load_dotenv(override=False)    # override=False — shell env wins over .env

# ── Ensure log directory exists ───────────────────────────────
LOG_DIR = os.environ.get('LOG_DIR', '/tmp/py-app/logs')
os.makedirs(LOG_DIR, exist_ok=True)

# ── Create Flask application ──────────────────────────────────
from app import create_app

ENV = os.environ.get('FLASK_ENV', 'production')
application = create_app(ENV)

# ── Debug info on startup ─────────────────────────────────────
if __name__ != '__main__':
    # Running under gunicorn
    import logging
    gunicorn_logger = logging.getLogger('gunicorn.error')
    application.logger.handlers  = gunicorn_logger.handlers
    application.logger.setLevel(gunicorn_logger.level)
    application.logger.info(
        f"App started — env={ENV} debug={application.debug}"
    )

# ── Direct run (python wsgi.py) ───────────────────────────────
if __name__ == '__main__':
    application.run(
        host='0.0.0.0',
        port=int(os.environ.get('PORT', 5000)),
        debug=False
    )