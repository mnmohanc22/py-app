import os


class Config:
    # Core
    SECRET_KEY      = os.environ.get("SECRET_KEY")
    APP_NAME        = os.environ.get("APP_NAME", "myapp")
    DEBUG           = os.environ.get("DEBUG", "false").lower() == "true"

    # Database
    SQLALCHEMY_DATABASE_URI        = os.environ.get("DATABASE_URL")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_POOL_SIZE           = int(os.environ.get("DB_POOL_SIZE", 5))
    SQLALCHEMY_MAX_OVERFLOW        = int(os.environ.get("DB_MAX_OVERFLOW", 10))
    SQLALCHEMY_POOL_TIMEOUT        = 30
    SQLALCHEMY_POOL_RECYCLE        = 1800
    SQLALCHEMY_ENGINE_OPTIONS      = {
        "pool_pre_ping": True,
        "pool_recycle": 1800,
    }

    # Session
    SESSION_COOKIE_SECURE   = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"

    # Logging
    LOG_DIR            = os.environ.get("LOG_DIR", "/tmp")
    LOG_LEVEL          = os.environ.get("LOG_LEVEL", "INFO")
    LOG_RETENTION_DAYS = int(os.environ.get("LOG_RETENTION_DAYS", 30))

    @staticmethod
    def validate():
        required = ["SECRET_KEY", "DATABASE_URL"]
        missing  = [k for k in required if not os.environ.get(k)]
        if missing:
            raise EnvironmentError(
                f"Missing required environment variables: {missing}"
            )
