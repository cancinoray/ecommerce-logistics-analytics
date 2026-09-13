# Custom Metabase image with the ClickHouse driver pre-installed.
#
# Metabase's ClickHouse driver is a community plugin, not bundled by default
# (see https://github.com/ClickHouse/metabase-clickhouse-driver). Baking the
# jar into the image sidesteps the "download then restart" dance a runtime
# script would need: the driver is present on first boot.
#
# Pinned versions:
#   - Metabase v0.50.24 (repo-wide pin, see docker-compose.yml)
#   - ClickHouse driver 1.50.7, the latest 1.50.x release series matching
#     Metabase 0.50.x. Verified 2026-09-13: sha256 of the live instance's
#     /plugins/clickhouse.metabase-driver.jar matches the upstream 1.50.7
#     release asset byte-for-byte.

FROM metabase/metabase:v0.50.24

# hadolint ignore=DL3022
ADD https://github.com/ClickHouse/metabase-clickhouse-driver/releases/download/1.50.7/clickhouse.metabase-driver.jar /plugins/clickhouse.metabase-driver.jar
