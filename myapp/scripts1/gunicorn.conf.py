# /opt/configs/gunicorn/app1.conf.py
import os
import multiprocessing
from dotenv import load_dotenv

load_dotenv("/opt/envs/app1.env", override=True)

bind             = os.environ.get("GUNICORN_BIND", "0.0.0.0:8001")
workers          = int(os.environ.get("GUNICORN_WORKERS", multiprocessing.cpu_count() * 2 + 1))
threads          = int(os.environ.get("GUNICORN_THREADS", 2))
worker_class     = "gthread"
timeout          = int(os.environ.get("GUNICORN_TIMEOUT", 120))
graceful_timeout = 30
preload_app      = True
daemon           = False

# ── PID file — outside source dir ────────────────────────────────
pidfile          = "/var/run/myapp/app1.pid"

# ── Logs — outside source dir ────────────────────────────────────
log_dir          = os.environ.get("LOG_DIR", "/var/log/myapp")
accesslog        = f"{log_dir}/gunicorn-access.log"
errorlog         = f"{log_dir}/gunicorn-error.log"
loglevel         = os.environ.get("LOG_LEVEL", "info").lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" in %(D)sµs'