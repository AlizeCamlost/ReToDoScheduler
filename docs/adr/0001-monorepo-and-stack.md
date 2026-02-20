# ADR 0001: Monorepo and Core Stack

## Status
Accepted

## Context
The project must deliver iPhone offline-first usage and web access while keeping logic maintainable for a single developer.

## Decision
Use a TypeScript monorepo with:
- React Native (Expo) for mobile
- React + Vite for web
- Fastify for API
- PostgreSQL for server persistence
- Shared `packages/core` for domain model and scheduling logic

## Consequences
- One shared language across clients/server reduces duplicated logic.
- Web and mobile can reuse parsing/scoring/scheduling behavior.
- API and persistence can evolve without forcing immediate client rewrites.
