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

echo "[deploy] Running migrations..."
COMPOSE_FILE="$COMPOSE_FILE" ENV_FILE="$ENV_FILE" \
  bash scripts/run-migrations.sh

echo "[deploy] Health check (retrying up to 30s)..."
for i in $(seq 1 10); do
  if curl -fsS http://127.0.0.1:3080/health >/tmp/retodo-health.json 2>/dev/null; then
    cat /tmp/retodo-health.json
    echo ""
    echo "[deploy] Completed."
    exit 0
  fi
  echo "  attempt $i failed, waiting 3s..."
  sleep 3
done
echo "[deploy] Health check failed after 30s" >&2
exit 1
