# Client Sync Quick Guide (MVP)

## Preconditions

- Server API is reachable from your phone and laptop.
- `GET http://<server-ip>:8787/health` returns `{ "ok": true, ... }`.

## Web setup

1. Start web app.
2. In the top server URL field, fill `http://<server-ip>:8787`.
3. Click `立即同步` once.

## iPhone setup

1. Open iOS app.
2. Fill server URL with `http://<server-ip>:8787`.
3. Tap `保存地址` then `立即同步`.

## Expected behavior

- Task changes in web are pushed within ~1 second and polled every 7 seconds.
- Task changes in iOS are pushed after actions and polled every 7 seconds.
- Conflict rule is LWW by `updatedAt`.

## Notes

- Delete is implemented as `archived` in MVP so cross-device sync can keep consistency.
- Current iOS build allows HTTP for quick testing. Move to HTTPS before production rollout.
