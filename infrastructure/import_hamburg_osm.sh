#!/usr/bin/env bash
set -euo pipefail

# Import an OSM PBF file into the running PostGIS container.
# Usage:
#   ./import_hamburg_osm.sh ../data/hamburg-latest.osm.pbf
# If no path is provided it defaults to ../data/hamburg-latest.osm.pbf

DATA_FILE=${1:-../data/hamburg-latest.osm.pbf}
PG_CONTAINER=portfolio-postgres
PG_USER=admin
PG_PASSWORD=supersecretpassword
PG_DATABASE=geodb
PG_PORT=5432
OSM2PGSQL_IMAGE=iboates/osm2pgsql:latest
CACHE_MB=2000

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATA_FILE=$(realpath "$SCRIPT_DIR/$DATA_FILE")
DATA_DIR=$(dirname "$DATA_FILE")

if [[ ! -f "$DATA_FILE" ]]; then
  echo "Error: OSM PBF file not found: $DATA_FILE" >&2
  exit 1
fi

NETWORK=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$PG_CONTAINER" | head -n 1)
if [[ -z "$NETWORK" ]]; then
  echo "Error: unable to determine Docker network for container '$PG_CONTAINER'." >&2
  echo "Make sure the postgres container is running." >&2
  exit 1
fi

echo "Using Docker network: $NETWORK"

echo "Enabling PostGIS and hstore extensions in database $PG_DATABASE..."
docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DATABASE" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DATABASE" -c "CREATE EXTENSION IF NOT EXISTS hstore;"

echo "Importing $DATA_FILE into PostgreSQL..."
docker run --rm \
  --network "$NETWORK" \
  -v "$DATA_DIR":"$DATA_DIR" \
  -e PGPASSWORD="$PG_PASSWORD" \
  -w "$DATA_DIR" \
  "$OSM2PGSQL_IMAGE" \
  --create \
  --slim \
  --drop \
  --hstore \
  --latlong \
  --cache "$CACHE_MB" \
  -d "$PG_DATABASE" \
  -U "$PG_USER" \
  -H "$PG_CONTAINER" \
  -P "$PG_PORT" \
  "$DATA_FILE"

echo "Import finished successfully."
