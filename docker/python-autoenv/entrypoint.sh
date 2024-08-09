#!/bin/sh

set -eu

python -m venv /venv

/venv/bin/pip install --no-cache-dir --upgrade pip

if [ -f "/app/packages.txt" ]; then
  apk add --update-cache --no-cache $(cat /app/packages.txt | tr '\n' ' ')
fi

if [ -f "/app/requirements.txt" ]; then
  /venv/bin/pip install --compile --no-cache-dir -r /app/requirements.txt
fi

exec /venv/bin/python "$@"
