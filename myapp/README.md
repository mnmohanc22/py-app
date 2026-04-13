# myapp — Flask + Gunicorn + systemd

## Structure

```
myapp/
├── api/
│   ├── __init__.py          # create_app() factory
│   ├── config.py            # single Config class from .env
│   ├── extensions.py        # db, migrate
│   ├── logging_config.py    # Python built-in daily log rotation
│   └── routes/
│       ├── __init__.py
│       └── users.py         # example blueprint
├── wsgi.py                  # WSGI entry point
├── gunicorn.conf.py         # Gunicorn configuration
├── myapp.service            # systemd unit file
├── requirements.txt
├── .env                     # real secrets — never commit
└── .env.example             # template — safe to commit
```

## Log Files

Python's `TimedRotatingFileHandler` handles all app log rotation internally:

| File | Content | Rotates |
|---|---|---|
| `/var/log/myapp/app.log` | All app logs (INFO+) | Daily at midnight UTC |
| `/var/log/myapp/error.log` | Errors only (WARNING+) | Daily at midnight UTC |
| `/var/log/myapp/gunicorn-access.log` | HTTP access log | Gunicorn managed |
| `/var/log/myapp/gunicorn-error.log` | Gunicorn worker errors | Gunicorn managed |

Rotated files are named: `app.log.2026-04-11`, `app.log.2026-04-10` etc.
Retention is controlled by `LOG_RETENTION_DAYS` in `.env`.

## Deploy

```bash
# 1. Clone and set up virtualenv
git clone https://github.com/yourorg/myapp /opt/myapp
cd /opt/myapp
python3 -m venv venv
venv/bin/pip install -r requirements.txt

# 2. Configure environment
cp .env.example .env
vi .env    # fill in SECRET_KEY, DATABASE_URL etc.

# 3. Test import
venv/bin/python -c "from api import create_app; print('OK')"

# 4. Install systemd service
cp myapp.service /etc/systemd/system/myapp.service
systemctl daemon-reload
systemctl enable myapp
systemctl start myapp
systemctl status myapp
```

## Operations

```bash
# Start / Stop / Restart
systemctl start myapp
systemctl stop myapp
systemctl restart myapp

# Reload workers without downtime (USR1)
systemctl reload myapp

# View logs
tail -f /var/log/myapp/app.log
tail -f /var/log/myapp/error.log
tail -f /var/log/myapp/gunicorn-access.log
journalctl -u myapp -f

# Flask shell
cd /opt/myapp
PYTHONPATH=/opt/myapp venv/bin/flask --app wsgi:app shell

# Run manually for debugging
venv/bin/python wsgi.py
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `SECRET_KEY` | ✅ | — | Flask session secret |
| `DATABASE_URL` | ✅ | — | PostgreSQL connection string |
| `DB_POOL_SIZE` | | 5 | SQLAlchemy pool size |
| `DB_MAX_OVERFLOW` | | 10 | SQLAlchemy max overflow |
| `GUNICORN_WORKERS` | | cpu*2+1 | Number of worker processes |
| `GUNICORN_THREADS` | | 2 | Threads per worker |
| `GUNICORN_BIND` | | 0.0.0.0:8000 | Bind address |
| `GUNICORN_TIMEOUT` | | 120 | Worker timeout seconds |
| `LOG_DIR` | | /var/log/myapp | Log directory |
| `LOG_LEVEL` | | INFO | Logging level |
| `LOG_RETENTION_DAYS` | | 30 | Days of logs to retain |
| `APP_NAME` | | myapp | Application name |
| `DEBUG` | | false | Enable debug mode |
