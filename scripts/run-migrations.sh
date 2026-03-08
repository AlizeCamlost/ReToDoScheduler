#!/usr/bin/env bash
# 增量 migration runner
# 用法：
#   本地开发：bash scripts/run-migrations.sh
#   生产部署：COMPOSE_FILE=deploy/docker-compose.prod.yml ENV_FILE=deploy/.env.prod bash scripts/run-migrations.sh
#
# 工作原理：
#   1. 在 DB 中创建 schema_migrations 追踪表（如果不存在）
#   2. 扫描 services/db/migrations/*.sql，按文件名排序
#   3. 跳过已记录的，按序执行未运行的 migration
#   4. 每个 migration 在单独事务中运行，失败则回滚，不记录版本号
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
ENV_FILE="${ENV_FILE:-}"
PG_USER="${POSTGRES_USER:-retodo}"
PG_DB="${POSTGRES_DB:-retodo}"
MIGRATION_DIR="services/db/migrations"

DC_ARGS=(-f "$COMPOSE_FILE")
if [[ -n "$ENV_FILE" ]]; then
  DC_ARGS+=(--env-file "$ENV_FILE")
fi

run_psql() {
  docker compose "${DC_ARGS[@]}" exec -T db psql -U "$PG_USER" -d "$PG_DB" "$@"
}

echo "[migrate] Using compose: $COMPOSE_FILE"

# 1. 创建追踪表
run_psql -q <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
SQL

# 2. 获取已执行的版本
APPLIED=$(run_psql -t -A -c "SELECT version FROM schema_migrations ORDER BY version;")

# 3. 按序执行未运行的 migration
PENDING=0
TOTAL=0

for filepath in "$MIGRATION_DIR"/*.sql; do
  [[ -f "$filepath" ]] || continue
  version=$(basename "$filepath")
  TOTAL=$((TOTAL + 1))

  if echo "$APPLIED" | grep -qFx "$version"; then
    echo "[migrate] $version — skip (already applied)"
    continue
  fi

  echo "[migrate] $version — applying..."
  if run_psql --single-transaction -f "/migrations/$version"; then
    run_psql -q -c "INSERT INTO schema_migrations (version) VALUES ('$version');"
    echo "[migrate] $version — done"
    PENDING=$((PENDING + 1))
  else
    echo "[migrate] $version — FAILED! Rolled back. Fix the SQL and re-run." >&2
    exit 1
  fi
done

echo "[migrate] Total: $TOTAL, newly applied: $PENDING"
