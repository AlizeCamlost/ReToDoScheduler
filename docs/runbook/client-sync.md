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

## iOS troubleshooting: `Network request failed`

1. In iPhone Safari open `http://<server-ip>:8787/health` first.
2. If Safari fails, fix server firewall/security-group (port `8787`) or use reverse proxy `443`.
3. If Safari works but app fails, reinstall latest iOS build from Xcode (to ensure latest Info.plist and sync code).
4. In app server URL field, use full URL with scheme (for example `http://1.2.3.4:8787`).
