from flask import Flask
from .config import Config
from .logging_config import setup_logging


def create_app():
    # 1. Validate required env vars before anything else
    Config.validate()

    # 2. Create Flask app
    app = Flask(__name__)
    app.config.from_object(Config)

    # 3. Setup logging (Python built-in daily rotation)
    setup_logging(app)

    # 5. Register blueprints
    from .routes.users import user_bp
    app.register_blueprint(user_bp, url_prefix="/api/users")

    # 6. Shell context for `flask shell`
    @app.shell_context_processor
    def make_shell_context():
        return {"app": app}

    app.logger.info(f"App '{app.config['APP_NAME']}' started")
    return app
