# 服务端部署

相关文档：

- [client-sync.md](client-sync.md)
- [recovery.md](recovery.md)

## 1. 适用范围

本指南用于部署 API + PostgreSQL，并作为 Web / iPhone 同步的服务端基础。

## 2. 前置条件

- Linux 服务器
- 已开放必要端口
- 已安装 Docker、Docker Compose、Git
- 已准备部署目录
- 已准备 `deploy/.env.prod`

仓库内已有部署入口：

- `.github/workflows/deploy.yml`
- `scripts/server-auto-deploy.sh`

## 3. 首次部署

### 3.1 拉取项目

```bash
cd /opt
sudo mkdir -p retodo
sudo chown $USER:$USER retodo
cd retodo
git clone <repo-url> .
```

### 3.2 配置环境变量

```bash
cp deploy/.env.prod.example deploy/.env.prod
vi deploy/.env.prod
```

至少设置：

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `API_AUTH_TOKEN`

### 3.3 构建并启动容器

```bash
COMPOSE_BAKE=false docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod build api
COMPOSE_BAKE=false docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod build web
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod up -d --no-build --remove-orphans
```

之所以拆成顺序 build + `up --no-build`，是为了规避某些服务器上 Docker Compose 被配置为默认委托给 Bake 后，在并行构建阶段触发内部解析错误的问题。

### 3.4 执行初始 migration

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /migrations/001_init.sql
```

如果当前 shell 没有加载 `.env.prod`：

```bash
set -a
source deploy/.env.prod
set +a
```

然后重新执行 migration。

## 4. 部署校验

```bash
curl http://127.0.0.1:8787/health
curl -H "Authorization: Bearer $API_AUTH_TOKEN" http://127.0.0.1:8787/v1/tasks
```

## 5. 日常运维

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod logs -f api
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod restart api
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod ps
```

有新 migration 时，进入数据库容器按同样方式执行对应 SQL 文件。

## 6. GitHub Actions 部署

当前推荐流程：

1. 本地整理提交并推送到 GitHub
2. 打开 GitHub Actions 的 `deploy` workflow
3. 选择分支并执行 `Run workflow`
4. 等待 workflow 通过 SSH 登录服务器并执行部署脚本

服务器工作区会以远端分支为准重新同步：

```bash
git fetch origin <branch>
git checkout -B <branch> origin/<branch>
git reset --hard origin/<branch>
```

这意味着：

- 强推送后的分支仍可部署
- 服务器目录不应保留人工未提交修改
- 若服务器上有未提交改动，workflow 应拒绝覆盖并输出 `git status`

当前仓库内的 `scripts/server-auto-deploy.sh` 会在远端按以下顺序执行：

1. 校验工作区干净并重置到目标分支
2. 清理旧容器名残留
3. 用 `COMPOSE_BAKE=false` 顺序构建 `api`、`web`
4. 执行 `docker compose up -d --no-build --remove-orphans`
5. 跑 migration 并做健康检查

如果 workflow 日志里再次出现 `load local bake definitions`，说明服务器环境仍有其他入口绕过了仓库脚本，应该优先检查是否有人手工执行了 `docker compose up --build`。

## 7. 备份基线

每日本地 dump 示例：

```bash
mkdir -p /opt/retodo/backups
0 4 * * * docker exec retodo-db pg_dump -U retodo retodo | gzip > /opt/retodo/backups/retodo-$(date +\%F).sql.gz
```

## 8. 安全边界

- 对公网暴露前优先接入域名和 HTTPS 反向代理
- 尽量限制 `8787` 的暴露范围
- 部署 key 使用最小权限用户，不要直接使用 root
- `docker compose` 项目名应显式固定，避免容器名和卷名漂移
- 服务器部署与 iOS 分发是两条不同流程，不应混用

恢复流程见 [recovery.md](recovery.md)。
