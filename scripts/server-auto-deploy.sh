#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/deploy/.env.prod"
COMPOSE_FILE="${ROOT_DIR}/deploy/docker-compose.prod.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy deploy/.env.prod.example and fill values first." >&2
  exit 1
fi

cd "$ROOT_DIR"

echo "[deploy] Pulling latest main..."
git fetch origin main
git checkout main
git pull --ff-only origin main

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

echo "[deploy] Rebuilding containers..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build

echo "[deploy] Running migration..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /migrations/001_init.sql

echo "[deploy] Health check..."
curl -fsS http://127.0.0.1:3080/health >/tmp/retodo-health.json
cat /tmp/retodo-health.json

echo "[deploy] Completed."
