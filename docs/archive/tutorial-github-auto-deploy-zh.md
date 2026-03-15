# GitHub 自动部署教程（中文）

本文对应需求 4：本地开发 -> push 到 GitHub -> 服务器自动拉取并自动重部署。

当前仓库已准备文件：

1. `/Users/camlostshi/Documents/ReToDoScheduler/.github/workflows/deploy.yml`
2. `/Users/camlostshi/Documents/ReToDoScheduler/scripts/server-auto-deploy.sh`

## 1. 目标架构

触发链路：

1. 你 push 到 `main`。
2. GitHub Actions 触发 `deploy` workflow。
3. Workflow 通过 SSH 登录服务器。
4. 在服务器执行 `scripts/server-auto-deploy.sh`：
   - `git pull --ff-only`
   - `docker compose up -d --build`
   - 运行 migration
   - 健康检查

## 2. 服务器前置准备（只做一次）

1. 服务器目录已有仓库（例如 `/opt/retodo`）。
2. 服务器里已有 `deploy/.env.prod` 且填好：
   - `POSTGRES_USER`
   - `POSTGRES_PASSWORD`
   - `POSTGRES_DB`
   - `API_AUTH_TOKEN`
3. 手动执行一次脚本，确认可用：

```bash
cd /opt/retodo
bash scripts/server-auto-deploy.sh
```

## 3. 生成部署用 SSH 密钥（建议专用）

在本地生成一对仅用于 CI 部署的 key：

```bash
ssh-keygen -t ed25519 -C "retodo-deploy" -f ~/.ssh/retodo_deploy
```

把公钥追加到服务器用户的 `~/.ssh/authorized_keys`：

```bash
cat ~/.ssh/retodo_deploy.pub | ssh <user>@<server-ip> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

## 4. 配置 GitHub Actions Secrets

在 GitHub 仓库 -> `Settings` -> `Secrets and variables` -> `Actions`，新增：

1. `DEPLOY_HOST`：服务器公网 IP
2. `DEPLOY_USER`：服务器登录用户（如 `ubuntu`）
3. `DEPLOY_PORT`：通常 `22`
4. `DEPLOY_PATH`：仓库在服务器路径（如 `/opt/retodo`）
5. `DEPLOY_SSH_KEY`：`~/.ssh/retodo_deploy` 私钥完整内容

## 5. 启用与验证自动部署

1. push 任意提交到 `main`。
2. 打开 GitHub `Actions`，查看 `deploy` workflow。
3. 成功后在服务器检查：

```bash
cd /opt/retodo
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod ps
curl http://127.0.0.1:8787/health
```

## 6. 常见失败与处理

1. `Error: missing server host`：`DEPLOY_HOST` 为空。到 GitHub 仓库 `Settings -> Secrets and variables -> Actions` 设置：
   - Secret `DEPLOY_HOST`，或 Variable `DEPLOY_HOST`
   - 推荐同时设置 `DEPLOY_USER`、`DEPLOY_PATH`（也支持 Secret/Variable）
   - `DEPLOY_SSH_KEY` 必须用 Secret
1. `Permission denied (publickey)`：`DEPLOY_SSH_KEY` 错或公钥未加入服务器。
2. `Missing deploy/.env.prod`：服务器未配置生产环境变量文件。
3. `API auth 401`：客户端 token 与服务端 `API_AUTH_TOKEN` 不一致。
4. migration 失败：先在服务器手动运行 `psql -f /migrations/001_init.sql` 看具体报错。

## 7. 回滚方案（手动）

部署失败可在服务器执行：

```bash
cd /opt/retodo
git log --oneline -n 5
git checkout <last-good-commit>
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod up -d --build
```

## 8. 安全建议

1. 部署 key 仅给服务器最小权限用户，不要用 root。
2. 服务器开启防火墙，仅开放必要端口。
3. 后续改为 HTTPS（80/443 + 反向代理）。
4. 定期轮换 `API_AUTH_TOKEN` 和部署 key。
> Archived tutorial. The current deployment truth source is [server-deploy.md](../server-deploy.md).
