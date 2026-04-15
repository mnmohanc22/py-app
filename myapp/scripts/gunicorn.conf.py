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
keepalive        = 5
preload_app      = True

# CRITICAL — shared PID file
# Both systemd PIDFile= and shell script read this
pidfile          = "/opt/pids/app1.pid"

# CRITICAL for systemd — never daemonize
# systemd tracks the process directly
daemon           = False

log_dir          = os.environ.get("LOG_DIR", "/opt/logs/app1")
accesslog        = f"{log_dir}/gunicorn-access.log"
errorlog         = f"{log_dir}/gunicorn-error.log"
loglevel         = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" in %(D)sµs'

def on_starting(server):
    server.log.info(f"Gunicorn starting — pidfile: {pidfile}")

def on_exit(server):
    server.log.info("Gunicorn exiting")

def post_fork(server, worker):
    server.log.info(f"Worker {worker.pid} forked")

def worker_abort(worker):
    worker.log.info(f"Worker {worker.pid} aborted")