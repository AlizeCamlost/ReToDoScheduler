# ADR 0002: Local-first with LWW Sync

## Status
Accepted

## Context
The app must remain fully usable offline and then synchronize automatically.

## Decision
- Local database is source of truth at interaction time.
- Network sync uses incremental operation logs.
- Conflict strategy in MVP is Last Write Wins (LWW).

## Consequences
- User interaction is not blocked by network quality.
- Sync design stays simple enough for a single-user system.
- Future text-level merge can be introduced by adding patch operations.
