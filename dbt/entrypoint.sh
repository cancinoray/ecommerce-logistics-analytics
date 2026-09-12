#!/bin/sh
# Sync the Python environment and dbt package dependencies on container
# start, so neither a pyproject.toml/uv.lock change nor a packages.yml
# change requires rebuilding the image. Afterwards exec the service
# command (default: tail -f /dev/null to keep alive).
set -e
uv sync --locked --no-install-project
dbt deps
exec "$@"
