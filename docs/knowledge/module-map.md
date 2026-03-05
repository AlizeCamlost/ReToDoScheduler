# Module Map

## packages/core
- Owns canonical domain types.
- Owns defaults and input normalization.
- Will own scheduler/rule engine implementation.

## apps/mobile
- iPhone-first entry point.
- Uses SQLite for local-first persistence.
- Provides basic sync via `/v1/tasks/sync` with server URL input.

## apps/web
- Browser execution and quick management.
- Uses server as source of truth and basic sync via `/v1/tasks/sync`.
- Uses fixed API URL + bearer token auth header.

## services/api
- Sync/backup/auth service boundary.
- Exposes `/health`, `/v1/tasks`, `/v1/tasks/sync` (LWW upsert).
- Protects `/v1/*` routes with bearer token check.

## services/db
- PostgreSQL migrations and DB-specific artifacts.
- Keeps schema lifecycle independent from API routing code.

## docs
- ADR: architecture decisions.
- domain: data model and business definitions.
- runbook: operational procedures (backup/recovery/deploy).
