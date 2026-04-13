import logging
import os
from logging.handlers import RotatingFileHandler
from flask import Flask


def _read_version():
    """Read version from VERSION file at project root."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    version_file = os.path.join(here, 'VERSION')
    with open(version_file, 'r') as f:
        return f.read().strip()

__version__ = _read_version()



def create_app(config_name=None):
    """Application factory."""
    app = Flask(__name__)
    

    config_name = config_name or os.environ.get('FLASK_ENV', 'production')
    app.config['VERSION'] = __version__

    from app.config import config
    app.config.from_object(config[config_name])

    from app.routes import main_bp
    app.register_blueprint(main_bp)

    configure_logging(app)
    return app


def configure_logging(app):
    log_dir  = app.config.get('LOG_DIR', '/opt/flaskapp/logs')
    log_file = os.path.join(log_dir, 'app.log')
    os.makedirs(log_dir, exist_ok=True)

    handler = RotatingFileHandler(
        log_file,
        maxBytes=10 * 1024 * 1024,
        backupCount=10
    )
    handler.setFormatter(logging.Formatter(
        '%(asctime)s %(levelname)s %(name)s %(threadName)s : %(message)s'
    ))
    handler.setLevel(logging.INFO)
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.INFO)
    app.logger.info('Flask application startup')
