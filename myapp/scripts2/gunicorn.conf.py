# /opt/myapp-project/configs/gunicorn/gunicorn.conf.py
#
# All paths resolved from PROJECT_ROOT env var
# Set by app1.sh before exec gunicorn:
#   export PROJECT_ROOT=/opt/myapp-project
#   export LOGS_RELATIVE=logs
#   export RUN_RELATIVE=run
#   export APP_NAME=myapp
#
# DO NOT call load_dotenv here
# .env is loaded by app1.sh before gunicorn starts

import os
import multiprocessing

# ════════════════════════════════════════════════════════════════
# STEP 1 — VALIDATE PROJECT_ROOT
# ════════════════════════════════════════════════════════════════

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", "").strip()

if not PROJECT_ROOT:
    raise EnvironmentError(
        "\n"
        "[gunicorn.conf] ERROR: PROJECT_ROOT is not set\n"
        "[gunicorn.conf] app1.sh must export PROJECT_ROOT before exec gunicorn\n"
        "[gunicorn.conf] Example: export PROJECT_ROOT=/opt/myapp-project\n"
    )

if not os.path.isdir(PROJECT_ROOT):
    raise FileNotFoundError(
        f"\n"
        f"[gunicorn.conf] ERROR: PROJECT_ROOT does not exist: {PROJECT_ROOT}\n"
        f"[gunicorn.conf] Run bootstrap.sh first to create project directories\n"
    )

# ════════════════════════════════════════════════════════════════
# STEP 2 — RESOLVE SUBDIRECTORY NAMES FROM ENV
# Defaults match bootstrap.vars values
# ════════════════════════════════════════════════════════════════

APP_NAME              = os.environ.get("APP_NAME",              "myapp")
APP_RELATIVE          = os.environ.get("APP_RELATIVE",          "app")
LOGS_RELATIVE         = os.environ.get("LOGS_RELATIVE",         "logs")
RUN_RELATIVE          = os.environ.get("RUN_RELATIVE",          "run")
CONFIGS_RELATIVE      = os.environ.get("CONFIGS_RELATIVE",      "configs")
VENV_RELATIVE         = os.environ.get("VENV_RELATIVE",         "venv")

# ════════════════════════════════════════════════════════════════
# STEP 3 — RESOLVE ABSOLUTE PATHS FROM PROJECT_ROOT
# ════════════════════════════════════════════════════════════════

# Source code dir
APP_DIR    = os.path.join(PROJECT_ROOT, APP_RELATIVE)

# Log dir — all gunicorn logs go here
LOG_DIR    = os.path.join(PROJECT_ROOT, LOGS_RELATIVE)

# Run dir — pid file goes here
RUN_DIR    = os.path.join(PROJECT_ROOT, RUN_RELATIVE)

# PID file — inside RUN_DIR
PID_FILE   = os.path.join(RUN_DIR, f"{APP_NAME}.pid")

# Venv dir — for reference/logging only
VENV_DIR   = os.path.join(PROJECT_ROOT, VENV_RELATIVE)

# ════════════════════════════════════════════════════════════════
# STEP 4 — VALIDATE RESOLVED DIRS EXIST
# ════════════════════════════════════════════════════════════════

def _validate_dir(path: str, label: str) -> None:
    """Raise if directory does not exist."""
    if not os.path.isdir(path):
        raise FileNotFoundError(
            f"\n"
            f"[gunicorn.conf] ERROR: {label} not found: {path}\n"
            f"[gunicorn.conf] Run bootstrap.sh to create all project directories\n"
        )

_validate_dir(PROJECT_ROOT, "PROJECT_ROOT")
_validate_dir(APP_DIR,      "APP_DIR")

# ════════════════════════════════════════════════════════════════
# STEP 5 — ENSURE RUNTIME DIRS EXIST
# Create LOG_DIR and RUN_DIR if missing
# These may not exist on first start
# ════════════════════════════════════════════════════════════════

def _ensure_dir(path: str, label: str) -> None:
    """Create directory if it does not exist."""
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)
        print(f"[gunicorn.conf] Created {label}: {path}")
    else:
        print(f"[gunicorn.conf] {label}: {path}")

_ensure_dir(LOG_DIR, "LOG_DIR")
_ensure_dir(RUN_DIR, "RUN_DIR")

# ════════════════════════════════════════════════════════════════
# STEP 6 — BINDING
# ════════════════════════════════════════════════════════════════

bind = os.environ.get("GUNICORN_BIND", "0.0.0.0:8001")

# ════════════════════════════════════════════════════════════════
# STEP 7 — WORKERS
# ════════════════════════════════════════════════════════════════

workers      = int(os.environ.get(
    "GUNICORN_WORKERS",
    multiprocessing.cpu_count() * 2 + 1
))
threads      = int(os.environ.get("GUNICORN_THREADS", 2))
worker_class = "gthread"

# ════════════════════════════════════════════════════════════════
# STEP 8 — TIMEOUTS
# ════════════════════════════════════════════════════════════════

timeout          = int(os.environ.get("GUNICORN_TIMEOUT",  120))
graceful_timeout = int(os.environ.get("GUNICORN_GRACEFUL", 30))
keepalive        = int(os.environ.get("GUNICORN_KEEPALIVE", 5))

# ════════════════════════════════════════════════════════════════
# STEP 9 — PROCESS MANAGEMENT
# ════════════════════════════════════════════════════════════════

# PID file — resolved from PROJECT_ROOT/run/<app_name>.pid
pidfile = PID_FILE

# Never daemonize — systemd or app1.sh manages the process
daemon = False

# Load app once in master then fork workers
# Saves memory via copy-on-write
preload_app = True

# ════════════════════════════════════════════════════════════════
# STEP 10 — LOGGING
# All logs inside PROJECT_ROOT/logs/
# ════════════════════════════════════════════════════════════════

# Gunicorn access log — one line per HTTP request
accesslog = os.path.join(LOG_DIR, "gunicorn-access.log")

# Gunicorn error log — worker lifecycle, unhandled exceptions
errorlog  = os.path.join(LOG_DIR, "gunicorn-error.log")

# Log level
loglevel  = os.environ.get("LOG_LEVEL", "info").lower()

# Access log format
access_log_format = (
    '%(h)s %(l)s %(u)s %(t)s '
    '"%(r)s" %(s)s %(b)s '
    '"%(f)s" "%(a)s" '
    'in %(D)sµs'
)

# ════════════════════════════════════════════════════════════════
# STEP 11 — SECURITY
# ════════════════════════════════════════════════════════════════

limit_request_line       = 4094
limit_request_fields     = 100
limit_request_field_size = 8190

# ════════════════════════════════════════════════════════════════
# STEP 12 — STARTUP SUMMARY
# ════════════════════════════════════════════════════════════════

print(
    f"\n"
    f"[gunicorn.conf] ════════════════════════════════════════════\n"
    f"[gunicorn.conf]  Gunicorn Configuration\n"
    f"[gunicorn.conf] ────────────────────────────────────────────\n"
    f"[gunicorn.conf]  PROJECT_ROOT  : {PROJECT_ROOT}\n"
    f"[gunicorn.conf]  APP_DIR       : {APP_DIR}\n"
    f"[gunicorn.conf]  LOG_DIR       : {LOG_DIR}\n"
    f"[gunicorn.conf]  RUN_DIR       : {RUN_DIR}\n"
    f"[gunicorn.conf]  pidfile       : {pidfile}\n"
    f"[gunicorn.conf]  accesslog     : {accesslog}\n"
    f"[gunicorn.conf]  errorlog      : {errorlog}\n"
    f"[gunicorn.conf]  bind          : {bind}\n"
    f"[gunicorn.conf]  workers       : {workers}\n"
    f"[gunicorn.conf]  threads       : {threads}\n"
    f"[gunicorn.conf]  worker_class  : {worker_class}\n"
    f"[gunicorn.conf]  timeout       : {timeout}s\n"
    f"[gunicorn.conf]  loglevel      : {loglevel}\n"
    f"[gunicorn.conf]  preload_app   : {preload_app}\n"
    f"[gunicorn.conf]  daemon        : {daemon}\n"
    f"[gunicorn.conf] ════════════════════════════════════════════\n"
)

# ════════════════════════════════════════════════════════════════
# STEP 13 — HOOKS
# ════════════════════════════════════════════════════════════════

def on_starting(server):
    server.log.info(
        f"Gunicorn starting | "
        f"app={APP_NAME} | "
        f"root={PROJECT_ROOT} | "
        f"bind={bind} | "
        f"workers={workers} | "
        f"pid={pidfile}"
    )

def on_exit(server):
    server.log.info(
        f"Gunicorn exiting | "
        f"app={APP_NAME} | "
        f"root={PROJECT_ROOT}"
    )

def post_fork(server, worker):
    server.log.info(
        f"Worker forked | "
        f"pid={worker.pid} | "
        f"app={APP_NAME}"
    )

def worker_int(worker):
    worker.log.warning(
        f"Worker interrupted | "
        f"pid={worker.pid}"
    )

def worker_abort(worker):
    worker.log.warning(
        f"Worker aborted | "
        f"pid={worker.pid}"
    )

def pre_exec(server):
    server.log.info(
        f"Gunicorn master restarting | "
        f"app={APP_NAME}"
    )

def on_reload(server):
    server.log.info(
        f"Gunicorn reloading | "
        f"logdir={LOG_DIR}"
    )