# Database Service

This directory owns database-specific artifacts.

## Contents

- `migrations/`: SQL migration files for PostgreSQL.

## Phase 1

- Migration `001_init.sql` defines base tables for tasks, task parts, windows, schedule blocks, learning events, and sync operation logs.

## Apply migration (example)

```bash
psql "$DATABASE_URL" -f services/db/migrations/001_init.sql
```
