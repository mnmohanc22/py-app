import os


class BaseConfig:
    SECRET_KEY         = os.environ.get('SECRET_KEY', 'change-me-in-production')
    LOG_DIR            = os.environ.get('LOG_DIR', '/opt/flaskapp/logs')
    JSON_SORT_KEYS     = False
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024


class ProductionConfig(BaseConfig):
    DEBUG               = False
    TESTING             = False
    PROPAGATE_EXCEPTIONS = True


class DevelopmentConfig(BaseConfig):
    DEBUG   = True
    LOG_DIR = '/tmp/flaskapp/logs'


config = {
    'production'  : ProductionConfig,
    'development' : DevelopmentConfig,
    'default'     : ProductionConfig,
}
