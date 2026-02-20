# Module Map

## packages/core
- Owns canonical domain types.
- Owns defaults and input normalization.
- Will own scheduler/rule engine implementation.

## apps/mobile
- iPhone-first entry point.
- Uses SQLite for local-first persistence.
- Will add background sync + backup trigger integration.

## apps/web
- Browser execution and quick management.
- Uses local storage in Phase 1 (will migrate to IndexedDB + sync parity).

## services/api
- Sync/backup/auth service boundary.
- Phase 1 keeps health endpoint and task endpoint placeholder.

## services/db
- PostgreSQL migrations and DB-specific artifacts.
- Keeps schema lifecycle independent from API routing code.

## docs
- ADR: architecture decisions.
- domain: data model and business definitions.
- runbook: operational procedures (backup/recovery/deploy).
