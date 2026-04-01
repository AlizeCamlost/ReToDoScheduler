#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/deploy/.env.prod"
COMPOSE_FILE="${ROOT_DIR}/deploy/docker-compose.prod.yml"
COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE")
API_IMAGE="retodoscheduler-api:latest"
WEB_IMAGE="retodoscheduler-web:latest"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy deploy/.env.prod.example first." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

DOCKER_BUILDKIT=0 docker build \
  --target runner \
  -f "$ROOT_DIR/services/api/Dockerfile" \
  -t "$API_IMAGE" \
  "$ROOT_DIR"

DOCKER_BUILDKIT=0 docker build \
  -f "$ROOT_DIR/apps/web/Dockerfile" \
  -t "$WEB_IMAGE" \
  --build-arg VITE_API_BASE_URL="" \
  --build-arg VITE_API_AUTH_TOKEN="$API_AUTH_TOKEN" \
  "$ROOT_DIR"

"${COMPOSE_CMD[@]}" up -d --no-build --remove-orphans

"${COMPOSE_CMD[@]}" \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /migrations/001_init.sql

echo "Deployment done. Health check: curl http://127.0.0.1:8787/health"
