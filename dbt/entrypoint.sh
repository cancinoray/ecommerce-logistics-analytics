#!/bin/sh
# Install dbt package dependencies on container start so a fresh
# container (or a packages.yml change) never fails with
# "only 0 package(s) installed in dbt_packages". Afterwards exec
# the service command (default: tail -f /dev/null to keep alive).
set -e
dbt deps
exec "$@"
