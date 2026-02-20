# Recovery Runbook (Draft)

## Local restore
1. Stop app process.
2. Restore latest local compressed snapshot.
3. Re-open app and verify task count + completion markers.

## Remote restore
1. Provision temporary PostgreSQL instance.
2. Restore weekly dump.
3. Replay sync operation logs after snapshot timestamp.
4. Point API to restored database and validate checksum.

## Validation checklist
- Task total count and done count match expected range.
- Latest updated tasks are present.
- Schedule blocks are internally consistent.
