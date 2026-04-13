"""
Gunicorn production configuration.
Bind to Unix socket — nginx proxies to this socket.
"""
import multiprocessing
import os

# ── Binding ───────────────────────────────────────────────────
bind            = 'unix:/run/flaskapp/flaskapp.sock'
backlog         = 2048

# ── Workers ───────────────────────────────────────────────────
workers         = (multiprocessing.cpu_count() * 2) + 1
worker_class    = 'sync'
worker_connections = 1000
threads         = 2
timeout         = 120
graceful_timeout= 30
keepalive       = 5

# ── Process naming ────────────────────────────────────────────
proc_name       = 'flaskapp'

# ── Logging ───────────────────────────────────────────────────
accesslog       = '/opt/flaskapp/logs/gunicorn-access.log'
errorlog        = '/opt/flaskapp/logs/gunicorn-error.log'
loglevel        = 'info'
capture_output  = True
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)sus'

# ── Security ──────────────────────────────────────────────────
limit_request_line   = 4096
limit_request_fields = 100
forwarded_allow_ips  = '127.0.0.1'

# ── Worker recycling (prevents memory leaks) ──────────────────
max_requests        = 1000
max_requests_jitter = 50

# ── Stats / health ────────────────────────────────────────────
statsd_host    = None
