# /opt/scripts/bootstrap.vars

# ════════════════════════════════════════════════════════════════
# APP IDENTITY
# ════════════════════════════════════════════════════════════════
APP_NAME=myapp
APP_USER=wlsapps
APP_GROUP=wlsapps

# ════════════════════════════════════════════════════════════════
# PROJECT ROOT — parent of all dirs
# ════════════════════════════════════════════════════════════════
PROJECT_ROOT=/opt/myapp-project

# ════════════════════════════════════════════════════════════════
# RELATIVE DIRS — all resolved from PROJECT_ROOT
# ════════════════════════════════════════════════════════════════
APP_RELATIVE=app
RELEASES_RELATIVE=releases
CONFIGS_RELATIVE=configs
GUNICORN_CONF_RELATIVE=configs/gunicorn
LOGS_RELATIVE=logs
RUN_RELATIVE=run
VENV_RELATIVE=venv

# ════════════════════════════════════════════════════════════════
# SCRIPTS
# ════════════════════════════════════════════════════════════════
SCRIPTS_DIR=/opt/scripts

# ════════════════════════════════════════════════════════════════
# SECRETS — outside project root
# ════════════════════════════════════════════════════════════════
ENVS_DIR=/opt/envs
ENV_FILE=/opt/envs/myapp.env

# ════════════════════════════════════════════════════════════════
# PYTHON
# ════════════════════════════════════════════════════════════════
PYTHON_MIN_VERSION=3.8
REQUIREMENTS_FILE=requirements.txt

# ════════════════════════════════════════════════════════════════
# GUNICORN — BINDING
# ════════════════════════════════════════════════════════════════

# Host and port gunicorn listens on
# Use 127.0.0.1:8001 if behind Nginx/Apache
# Use 0.0.0.0:8001 for direct access
GUNICORN_BIND=0.0.0.0:8001

# ════════════════════════════════════════════════════════════════
# GUNICORN — WORKERS
# ════════════════════════════════════════════════════════════════

# Number of worker processes
# Rule of thumb: (CPU cores x 2) + 1
# 2 core = 5   4 core = 9   8 core = 17
# Set explicitly to avoid surprises in production
GUNICORN_WORKERS=5

# Threads per worker
# gthread worker class uses threads for concurrency
# Each worker handles: GUNICORN_THREADS requests at a time
# Total concurrency = GUNICORN_WORKERS x GUNICORN_THREADS
GUNICORN_THREADS=2

# Worker class
# gthread  — thread-based, best for Flask + SQLAlchemy
# sync     — single threaded, one request per worker
# gevent   — async green threads (needs gevent installed)
GUNICORN_WORKER_CLASS=gthread

# Max requests before worker is gracefully restarted
# Prevents memory leaks from growing indefinitely
# 0 = never restart
GUNICORN_MAX_REQUESTS=1000

# Random jitter added to max_requests
# Prevents all workers restarting at the same time
GUNICORN_MAX_REQUESTS_JITTER=100

# ════════════════════════════════════════════════════════════════
# GUNICORN — TIMEOUTS
# ════════════════════════════════════════════════════════════════

# Worker timeout in seconds
# If worker does not respond within this time it is killed
# Increase for long-running requests (file uploads, reports)
GUNICORN_TIMEOUT=120

# Graceful timeout on shutdown
# Time for workers to finish current requests on SIGTERM
GUNICORN_GRACEFUL_TIMEOUT=30

# Keep-alive timeout for idle connections
# How long to wait for next request on a persistent connection
GUNICORN_KEEPALIVE=5

# ════════════════════════════════════════════════════════════════
# GUNICORN — LOGGING
# ════════════════════════════════════════════════════════════════

# Log level: debug, info, warning, error, critical
LOG_LEVEL=info

# Log retention in days (used by Flask TimedRotatingFileHandler)
LOG_RETENTION_DAYS=30

# ════════════════════════════════════════════════════════════════
# GUNICORN — SECURITY
# ════════════════════════════════════════════════════════════════

# Max size of HTTP request line in bytes
# Protects against oversized URL attacks
GUNICORN_LIMIT_REQUEST_LINE=4094

# Max number of HTTP headers
# Protects against header flooding attacks
GUNICORN_LIMIT_REQUEST_FIELDS=100

# Max size of each HTTP header value in bytes
GUNICORN_LIMIT_REQUEST_FIELD_SIZE=8190

# ════════════════════════════════════════════════════════════════
# ADO GIT
# ════════════════════════════════════════════════════════════════
ADO_ORG=your-org
ADO_PROJECT=your-project
ADO_REPO=your-repo
ADO_PAT=your-personal-access-token

# ════════════════════════════════════════════════════════════════
# RELEASE MANAGEMENT
# ════════════════════════════════════════════════════════════════
KEEP_RELEASES=5