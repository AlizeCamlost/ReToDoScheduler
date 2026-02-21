#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/deploy/.env.prod"
COMPOSE_FILE="${ROOT_DIR}/deploy/docker-compose.prod.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy deploy/.env.prod.example first." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /migrations/001_init.sql

echo "Deployment done. Health check: curl http://127.0.0.1:8787/health"
