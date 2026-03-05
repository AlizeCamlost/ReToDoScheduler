# Server Deploy Guide (Tencent Cloud, 2C2G)

This guide deploys API + PostgreSQL for ReToDoScheduler before Phase 2.

## 0. Server prerequisites

- OS: Ubuntu-like Linux
- Open ports: `22`, `8787` (temporary), later `80/443` after domain + reverse proxy

Install Docker:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git
sudo usermod -aG docker $USER
newgrp docker
```

## 1. Pull project

```bash
cd /opt
sudo mkdir -p retodo
sudo chown $USER:$USER retodo
cd retodo
git clone <your-repo-url> .
```

## 2. Configure production env

```bash
cp deploy/.env.prod.example deploy/.env.prod
vi deploy/.env.prod
```

Set strong database password.
Set a strong random `API_AUTH_TOKEN` as well.

## 3. Build and start containers

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod up -d --build
```

## 4. Run initial migration

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /migrations/001_init.sql
```

If your shell doesn't export vars from `.env.prod`, run:

```bash
set -a
source deploy/.env.prod
set +a
```

Then rerun migration command.

## 5. Health check

```bash
curl http://127.0.0.1:8787/health
```

Expected response:

```json
{"ok":true,"service":"retodo-api","timestamp":"..."}
```

Validate protected route:

```bash
curl -H "Authorization: Bearer $API_AUTH_TOKEN" http://127.0.0.1:8787/v1/tasks
```

## 6. Log and restart ops

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod logs -f api
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod restart api
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod ps
```

## 7. Security notes (recommended before mobile sync rollout)

- Prefer domain + HTTPS reverse proxy before exposing to internet.
- Keep `8787` restricted by firewall if possible.
- Add fail2ban / basic rate limit at proxy layer.

## 8. Backup baseline (server-side)

Daily local dump example:

```bash
mkdir -p /opt/retodo/backups
0 4 * * * docker exec retodo-db pg_dump -U retodo retodo | gzip > /opt/retodo/backups/retodo-$(date +\%F).sql.gz
```

Then sync to Tencent COS weekly (next step to automate in CI/cron).

## 9. Auto deploy helper

Server-side helper script:

```bash
cd /opt/retodo
bash scripts/server-auto-deploy.sh
```

GitHub Actions setup tutorial:

- `docs/tutorial/github-auto-deploy-zh.md`
