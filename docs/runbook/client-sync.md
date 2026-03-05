# Client Sync Quick Guide (MVP)

## Preconditions

- Server API is reachable from your phone and laptop.
- `GET http://<server-ip>:8787/health` returns `{ "ok": true, ... }`.
- Server has `API_AUTH_TOKEN` configured.
- Web and iOS clients use the same auth token.

## Token setup

### Web

```bash
cp apps/web/.env.example apps/web/.env
```

Set `VITE_API_AUTH_TOKEN` in `apps/web/.env`.

### iOS

```bash
cp apps/mobile/.env.example apps/mobile/.env
```

Set `EXPO_PUBLIC_API_AUTH_TOKEN` in `apps/mobile/.env`.

Then reinstall iOS app from Xcode (`Cmd + R`) to refresh runtime config.

## Fixed server URL behavior

- Web uses built-in API URL: `http://43.159.136.45:8787`.
- iOS uses built-in API URL: `http://43.159.136.45:8787`.
- UI no longer exposes editable server URL field.

## Expected behavior

- Task changes in web are pushed immediately and polled every 7 seconds.
- Task changes in iOS are pushed after actions and polled every 7 seconds.
- Drag-reorder rank is synchronized by `extJson.rank` and rendered consistently.
- Conflict rule is LWW by `updatedAt`.

## Notes

- Delete is implemented as `archived` in MVP so cross-device sync can keep consistency.
- Current iOS build allows HTTP for quick testing. Move to HTTPS before production rollout.

## iOS troubleshooting: `Network request failed`

1. In iPhone Safari open `http://43.159.136.45:8787/health` first.
2. If Safari fails, fix server firewall/security-group (port `8787`) or use reverse proxy `443`.
3. If Safari works but app fails, reinstall latest iOS build from Xcode.
4. Check token mismatch: server `API_AUTH_TOKEN` must equal iOS `EXPO_PUBLIC_API_AUTH_TOKEN`.
