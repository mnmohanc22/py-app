import os
import multiprocessing

# ── Binding ───────────────────────────────────────────────────────────────────
bind = os.environ.get("GUNICORN_BIND", "0.0.0.0:8000")

# ── Workers ───────────────────────────────────────────────────────────────────
# gthread: thread-based worker, ideal for Flask + SQLAlchemy
workers      = int(os.environ.get("GUNICORN_WORKERS", multiprocessing.cpu_count() * 2 + 1))
threads      = int(os.environ.get("GUNICORN_THREADS", 2))
worker_class = "gthread"

# ── Timeouts ──────────────────────────────────────────────────────────────────
timeout          = int(os.environ.get("GUNICORN_TIMEOUT", 120))
graceful_timeout = 30       # seconds for workers to finish on SIGTERM
keepalive        = 5        # seconds to hold idle connections open

# ── Process management ────────────────────────────────────────────────────────
pidfile     = "/tmp/gunicorn.pid"
daemon      = False         # systemd manages the process lifecycle
preload_app = True          # load app in master before forking (saves memory)

# ── Logging ───────────────────────────────────────────────────────────────────
# Python's TimedRotatingFileHandler manages app.log and error.log
# Gunicorn manages its own access and error logs below
log_dir   = os.environ.get("LOG_DIR", "/tmp/")
accesslog = f"{log_dir}/gunicorn-access.log"
errorlog  = f"{log_dir}/gunicorn-error.log"
loglevel  = os.environ.get("LOG_LEVEL", "info").lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" in %(D)sµs'

# ── Security ──────────────────────────────────────────────────────────────────
limit_request_line       = 4094
limit_request_fields     = 100
limit_request_field_size = 8190

# ── Server hooks ──────────────────────────────────────────────────────────────
def on_starting(server):
    server.log.info("Gunicorn master starting")

def on_exit(server):
    server.log.info("Gunicorn master exiting")

def worker_int(worker):
    worker.log.info(f"Worker {worker.pid} interrupted")

def worker_abort(worker):
    worker.log.info(f"Worker {worker.pid} aborted")

def post_fork(server, worker):
    server.log.info(f"Worker {worker.pid} forked")
