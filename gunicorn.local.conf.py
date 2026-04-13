# gunicorn.local.conf.py — full production-like local config

import os
import multiprocessing

# ── Log directory ─────────────────────────────────────────────
LOG_DIR = os.environ.get('LOG_DIR', '/tmp/py-app/logs')
os.makedirs(LOG_DIR, exist_ok=True)

# ─────────────────────────────────────────────────────────────
# BINDING
# ─────────────────────────────────────────────────────────────

# Mac — TCP port (Unix socket not available on Mac)
bind    = '127.0.0.1:8000'
backlog = 2048              # max queued connections waiting for a worker

# Linux/RHEL — Unix socket (used in production)
# bind = 'unix:/run/py-app/py-app.sock'

# ─────────────────────────────────────────────────────────────
# WORKERS
# ─────────────────────────────────────────────────────────────

# Worker type
worker_class = 'sync'           # sync | gthread | gevent

# Number of worker processes
workers      = (multiprocessing.cpu_count() * 2) + 1

# Threads per worker (only used with gthread)
threads      = 1

# Max simultaneous connections (only used with gevent)
worker_connections = 1000

# ─────────────────────────────────────────────────────────────
# TIMEOUTS
# ─────────────────────────────────────────────────────────────

# Seconds before killing an unresponsive worker
timeout         = 120

# Seconds to wait for graceful worker shutdown on reload
graceful_timeout = 30

# Seconds for client to send a request after connecting
keepalive       = 5

# ─────────────────────────────────────────────────────────────
# REQUESTS
# ─────────────────────────────────────────────────────────────

# Max requests per worker before it is recycled
# Prevents memory leaks growing indefinitely
max_requests        = 1000

# Random jitter added to max_requests
# Prevents all workers restarting at same time
max_requests_jitter = 100

# ─────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────

# Access log — every request logged here
accesslog = os.path.join(LOG_DIR, 'gunicorn-access.log')

# Error log — worker errors, startup info
errorlog  = os.path.join(LOG_DIR, 'gunicorn-error.log')

# Log level: debug | info | warning | error | critical
loglevel  = 'info'

# Capture stdout/stderr from Flask app into error log
capture_output = True

# Include worker process ID in log lines
enable_stdio_inheritance = True

# Custom access log format
# %h=host %l=ident %u=user %t=time %r=request %s=status %b=bytes %f=referer %a=agent %D=microseconds
access_log_format = (
    '%(h)s %(l)s %(u)s %(t)s '
    '"%(r)s" %(s)s %(b)s '
    '"%(f)s" "%(a)s" '
    '%(D)sus'               # response time in microseconds
)

# ─────────────────────────────────────────────────────────────
# PROCESS
# ─────────────────────────────────────────────────────────────

# Process name shown in ps aux
proc_name = 'py-app'

# Auto reload workers when code changes (dev only — remove in prod)
reload = True

# Files to watch for reload triggers
reload_extra_files = [
    'app/config.py',
    'app/routes.py',
    '.env',
]

# ─────────────────────────────────────────────────────────────
# SECURITY
# ─────────────────────────────────────────────────────────────

# Max size of HTTP request line in bytes
limit_request_line = 4096

# Max number of HTTP request headers
limit_request_fields = 100

# Max size of each HTTP request header in bytes
limit_request_field_size = 8190

# Trust X-Forwarded-For header from these IPs only
# (prevents IP spoofing when behind nginx)
forwarded_allow_ips = '127.0.0.1'

# ─────────────────────────────────────────────────────────────
# SERVER HOOKS — lifecycle callbacks
# ─────────────────────────────────────────────────────────────

def on_starting(server):
    """Called just before master process is initialized."""
    print(f"[gunicorn] Starting — workers={workers} bind={bind}")


def on_reload(server):
    """Called before reloading workers after code change."""
    print("[gunicorn] Reloading workers...")


def worker_init(worker):
    """Called just after a worker has been forked."""
    print(f"[gunicorn] Worker {worker.pid} starting")


def worker_exit(server, worker):
    """Called when a worker exits."""
    print(f"[gunicorn] Worker {worker.pid} exited")


def on_exit(server):
    """Called just before the master exits."""
    print("[gunicorn] Master shutting down")