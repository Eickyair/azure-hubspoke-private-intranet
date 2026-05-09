#!/bin/sh
set -e

cd /home/site/wwwroot

if [ ! -f main.py ] && [ -f output.tar.zst ]; then
  tar --zstd -xf output.tar.zst -C /home/site/wwwroot
fi

export PYTHONPATH="/home/site/wwwroot:/home/site/wwwroot/antenv/lib/python3.11/site-packages:${PYTHONPATH}"

exec python -m uvicorn main:app --host 0.0.0.0 --port 8000