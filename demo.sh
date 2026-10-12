#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
if [ -x .venv/bin/python ]; then
  exec .venv/bin/python run.py "${1:-demo}"
fi
exec python3 run.py "${1:-demo}"
