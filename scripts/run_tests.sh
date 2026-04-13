# scripts/run_tests.sh
#!/bin/bash
set -e
source venv/bin/activate
pytest tests/ -v --cov=app --cov-report=term-missing