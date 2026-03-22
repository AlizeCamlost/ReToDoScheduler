# ReToDoScheduler

ReToDoScheduler is a local-first todo scheduler for iPhone + Web with incremental sync.

## Workspace layout

- `apps/mobile`: native SwiftUI iPhone client with local persistence.
- `apps/web`: React + Vite SPA for browser access (runs as local dev server on mac).
- `services/api`: Fastify API service.
- `services/db`: PostgreSQL migrations and database service artifacts.
- `packages/core`: shared domain model and rules:
  - `norn/*`: stable core model and ordering surface.
  - `kairos/*`: dynamic decision cursor (rank/strategy metadata).
- `docs`: current specs, runbooks, ADRs, and archived drafts.

## Quick start

```bash
npm install
npm run dev:web
npm run dev:mobile
npm run dev:api
npm run dev:db:up
npm run ios:prepare
```

Before running sync-enabled clients, configure the Web auth token locally:

```bash
cp apps/web/.env.example apps/web/.env
```

## Current status (Phase 1)

- Monorepo scaffold is ready.
- Core task model and defaults are implemented.
- Web uses server as source of truth (no local task persistence) with basic sync.
- Mobile local CRUD + basic server sync is implemented in the native SwiftUI app.
- API has `/health`, `/v1/tasks`, and `/v1/tasks/sync`.

## Next steps

- Implement deterministic scheduler and Kairos decision-cursor persistence.
- Evolve from full-list sync to `sync_ops` incremental cursor sync.
- Add backup jobs and restore runbook automation.

## Sync setup (MVP)

- Start API server and ensure `GET /health` works.
- Set `API_AUTH_TOKEN` on server and same token in:
  - `apps/web/.env` as `VITE_API_AUTH_TOKEN`
  - iPhone app `设置` page as `API Auth Token`
- Web uses the built-in fixed API URL (`http://43.159.136.45:8787`).
- iPhone app reads API URL from its in-app settings page.
- Trigger `立即同步` on either side. The other side will receive updates on next poll.

## Deployment

- Docs index: `docs/README.md`
- Architecture: `docs/specs/architecture.md`
- Product model: `docs/specs/product-model.md`
- Scheduling model: `docs/specs/scheduling-model.md`
- Server deploy runbook: `docs/runbooks/server-deploy.md`
- iOS setup runbook: `docs/runbooks/ios.md`
- Client sync runbook: `docs/runbooks/client-sync.md`
- Recovery runbook: `docs/runbooks/recovery.md`
