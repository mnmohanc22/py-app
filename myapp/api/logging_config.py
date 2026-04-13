import os
import logging
from logging.handlers import TimedRotatingFileHandler


def _make_handler(filepath: str, level: int, days: int, formatter: logging.Formatter) -> TimedRotatingFileHandler:
    """
    Create a TimedRotatingFileHandler that:
      - rotates daily at midnight UTC
      - keeps `days` backup files
      - names rotated files: app.log.2026-04-11, app.log.2026-04-10 ...
      - compresses rotated files using gzip
    """
    handler = TimedRotatingFileHandler(
        filename=filepath,
        when="midnight",        # rotate at midnight every day
        interval=1,             # every 1 day
        backupCount=days,       # number of rotated files to retain
        encoding="utf-8",
        utc=True,               # use UTC for rotation boundary
        delay=False,            # open file immediately on startup
    )
    handler.suffix  = "%Y-%m-%d"          # rotated filename suffix
    handler.setFormatter(formatter)
    handler.setLevel(level)
    return handler


def setup_logging(app):
    log_dir = app.config["LOG_DIR"]
    level   = getattr(logging, app.config["LOG_LEVEL"].upper(), logging.INFO)
    days    = app.config["LOG_RETENTION_DAYS"]

    os.makedirs(log_dir, exist_ok=True)

    formatter = logging.Formatter(
        fmt="[%(asctime)s] %(levelname)s [%(name)s] %(module)s:%(lineno)d — %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # ── app.log — all levels (INFO and above by default) ────────
    app_handler = _make_handler(
        filepath=os.path.join(log_dir, "app.log"),
        level=level,
        days=days,
        formatter=formatter,
    )

    # ── error.log — WARNING and above only ──────────────────────
    error_handler = _make_handler(
        filepath=os.path.join(log_dir, "error.log"),
        level=logging.WARNING,
        days=days,
        formatter=formatter,
    )

    # ── Attach handlers to Flask logger ─────────────────────────
    app.logger.handlers.clear()
    app.logger.addHandler(app_handler)
    app.logger.addHandler(error_handler)
    app.logger.setLevel(level)

    # ── Also capture gunicorn.error into app logger ─────────────
    gunicorn_logger = logging.getLogger("gunicorn.error")
    for handler in gunicorn_logger.handlers:
        app.logger.addHandler(handler)

    app.logger.info(
        f"Logging initialized | "
        f"level={app.config['LOG_LEVEL']} | "
        f"dir={log_dir} | "
        f"retention={days} days | "
        f"rotation=daily at midnight UTC"
    )
