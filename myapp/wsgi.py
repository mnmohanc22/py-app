import os
from dotenv import load_dotenv

# Load .env before importing api package
# override=True ensures .env values take precedence over existing shell vars
load_dotenv(dotenv_path=".env", override=True)

from api import create_app

app         = create_app()
application = app           # standard WSGI callable for gunicorn/uWSGI

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 8000)),
    )
