# ReToDoScheduler

Local-first todo scheduler for iPhone + Web with incremental sync.

## Workspace layout

- `apps/mobile`: React Native (Expo) iPhone client with SQLite local persistence.
- `apps/web`: React + Vite SPA for browser access (runs as local dev server on mac).
- `services/api`: Fastify API service.
- `services/db`: PostgreSQL migrations and database service artifacts.
- `packages/core`: shared domain model, defaults, lightweight NLP parser, and scoring utilities.
- `docs`: ADRs, domain docs, and runbooks.

## Quick start

```bash
npm install
npm run dev:web
npm run dev:mobile
npm run dev:api
npm run dev:db:up
npm --prefix apps/mobile run prebuild:ios
```

## Current status (Phase 1)

- Monorepo scaffold is ready.
- Core task model and defaults are implemented.
- Web offline local CRUD demo is implemented.
- Mobile SQLite local CRUD minimal flow is implemented.
- API service has health endpoint and task sync placeholder endpoint.

## Next steps

- Implement deterministic scheduler and rule engine persistence.
- Add real sync protocol with `sync_ops` cursor.
- Add backup jobs and restore runbook automation.

## Deployment

- Server deploy runbook: `docs/runbook/server-deploy.md`
- iPhone install runbook: `docs/runbook/ios-device-install.md`
