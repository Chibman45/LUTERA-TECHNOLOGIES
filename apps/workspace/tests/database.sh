#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container="lutera-workspace-test-${RANDOM}"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run --rm --name "$container" -e POSTGRES_HOST_AUTH_METHOD=trust -d postgres:17-alpine >/dev/null
for attempt in {1..40}; do
  # The image starts a temporary Unix-socket server during initdb. Wait for the
  # final TCP listener so tests cannot race that temporary server's shutdown.
  if docker exec "$container" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec -i "$container" psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 < tests/database-auth-stub.sql
for migration in supabase/migrations/*.sql; do
  docker exec -i "$container" psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 < "$migration"
done
docker exec -i "$container" psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 < tests/access.sql

docker exec -i "$container" psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 < tests/account-access.sql
