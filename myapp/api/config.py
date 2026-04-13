import os


class Config:
    # Core
    SECRET_KEY      = os.environ.get("SECRET_KEY")
    APP_NAME        = os.environ.get("APP_NAME", "myapp")
    DEBUG           = os.environ.get("DEBUG", "false").lower() == "true"

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
        required = ["SECRET_KEY"]
        missing  = [k for k in required if not os.environ.get(k)]
        if missing:
            raise EnvironmentError(
                f"Missing required environment variables: {missing}"
            )
