# ReToDoScheduler

ReToDoScheduler is a local-first task pool and rolling scheduler for Web + iPhone. The current product surface is organized around three top-level views shared across clients:

- `Sequence`: current focus, current sequence, upcoming work, and quick add.
- `Task Pool`: directory / canvas organization, task detail flow, import/export, and sync entrypoints.
- `Schedule`: time templates and horizon-based derived schedule.

The repository keeps product semantics in shared docs and shared core types, while Web, iPhone, API, and database evolve around the same task and sync contract. For now, Web remains the primary desktop-class editing surface; iPhone stays optimized for quick capture and quick reading. If the product is later wrapped as a native desktop app, that packaging should still preserve the current Web information architecture instead of creating a second desktop-specific product shell.

## Workspace layout

- `apps/mobile`: native iPhone clients and Xcode projects. The current maintained iPhone app lives in `apps/mobile/ios_ng/Norn/Norn`.
- `apps/web`: React + Vite browser client. It is the current desktop-oriented editing surface and the future desktop packaging base.
- `services/api`: Fastify API for health checks, task reads, and sync.
- `services/db`: PostgreSQL migrations and DB service artifacts.
- `packages/core`: shared task model, task-pool organization model, defaults, ordering helpers, and scheduler logic.
- `docs`: specs, runbooks, ADRs, guides, and archived material. Start with `docs/README.md`.

## Quick start

Install dependencies:

```bash
npm install
```

Optional: prefill default Web API base URL locally:

```bash
cp apps/web/.env.example apps/web/.env
```

Start the local stack:

```bash
npm run dev:db:up
npm run dev:db:migrate
npm run dev:api
npm run dev:web
```

Then open Web and log in with the development defaults:

- username: `owner`
- password: `retodo-dev-login`

For iPhone development, open the Xcode project directly:

- `apps/mobile/ios_ng/Norn/Norn.xcodeproj`

If you want a helper command, keep only this one:

```bash
npm run ios:open
```

It only opens the same Xcode project. The primary workflow is still launching and running from Xcode GUI.

For the exact iPhone workflow, signing steps, and sync setup, use `docs/runbooks/ios.md`.

## Current behavior

- Clients maintain local state first, then reconcile with the server.
- The API exposes `GET /health`, `GET /v1/auth/session`, `POST /v1/auth/login`, `POST /v1/auth/logout`, `GET /v1/auth/sessions`, `POST /v1/auth/sessions/revoke`, `POST /v1/auth/sessions/revoke-others`, `GET /v1/tasks`, and `POST /v1/tasks/sync`.
- Task sync is still full-list + LWW by `updatedAt`.
- Task-pool organization sync travels in parallel as `taskPoolOrganization`, covering both directory tree and canvas layout.
- Web uses owner login plus long-lived HttpOnly session cookies; theme mode and display preferences live in browser storage, and `.env` only provides the initial API base URL.
- iPhone sync settings are configured inside the app and still use `API_AUTH_TOKEN`.

## Docs map

- Repo docs index: `docs/README.md`
- System architecture: `docs/specs/architecture.md`
- Product semantics: `docs/specs/product-model.md`
- Scheduling model: `docs/specs/scheduling-model.md`
- Web structure: `docs/specs/web-app-structure.md`
- iPhone structure: `docs/specs/norn-mobile-structure.md`
- Client sync runbook: `docs/runbooks/client-sync.md`
- iOS runbook: `docs/runbooks/ios.md`
- Server deploy runbook: `docs/runbooks/server-deploy.md`
- Recovery runbook: `docs/runbooks/recovery.md`

## Working rule

If implementation behavior, interaction semantics, or repository structure changes, update the corresponding active docs in `docs/` together with the code. The root `README.md` is the repo entrypoint; `docs/README.md` is the detailed document index.
