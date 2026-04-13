# scripts/run_dev.sh
#!/bin/bash
set -e
export FLASK_ENV=development
export FLASK_APP=wsgi:application
source venv/bin/activate
flask run --host=0.0.0.0 --port=5000 --reload