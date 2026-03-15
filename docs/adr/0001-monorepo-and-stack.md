# ADR 0001: Monorepo and Core Stack

## Status
Accepted

## Context
The project must deliver iPhone offline-first usage and web access while keeping logic maintainable for a single developer.

## Decision
Use a TypeScript monorepo with:
- native SwiftUI for mobile
- React + Vite for web
- Fastify for API
- PostgreSQL for server persistence
- Shared `packages/core` for domain model and scheduling logic

## Consequences
- One shared language across web/server reduces duplicated logic.
- Web reuses `packages/core`; mobile keeps a native Swift implementation aligned to the same domain model.
- API and persistence can evolve without forcing immediate client rewrites.
