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
- `WEB_LOGIN_USERNAME`
- `WEB_LOGIN_PASSWORD`
- `WEB_SESSION_COOKIE_SECURE`

建议值：

- 正常公网部署、有 HTTPS：`WEB_SESSION_COOKIE_SECURE=true`
- 临时 HTTP-only 部署：`WEB_SESSION_COOKIE_SECURE=false`

### 3.3 构建并启动容器

```bash
DOCKER_BUILDKIT=0 docker build --target runner -f services/api/Dockerfile -t retodoscheduler-api:latest .
DOCKER_BUILDKIT=0 docker build -f apps/web/Dockerfile -t retodoscheduler-web:latest \
  --build-arg VITE_API_BASE_URL="" .
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod up -d --no-build --remove-orphans
```

之所以改成显式 `docker build` + `up --no-build`，是因为某些服务器上 Docker Compose 即使设置了 `COMPOSE_BAKE=false`，仍会被本机默认 builder 配置强制委托给 Bake，并在构建结束前后触发内部解析错误。这里直接绕过 `docker compose build`，并用 `DOCKER_BUILDKIT=0` 强制回退到 legacy builder。

当前这套做法按“过渡性部署修复”对待，而不是长期目标架构。考虑到业务形态和仓库结构仍在演进，现阶段先以稳定部署为优先，不主动收敛这套 workaround。等后续业务边界、目录结构和镜像输入范围相对稳定，并且需要重新审视部署技术债时，再集中评估是否要：

- 为仓库根目录补充真正生效的 `.dockerignore`
- 收窄 `api` / `web` 的 build context
- 取消 `DOCKER_BUILDKIT=0 docker build` workaround，回到更干净的生产构建路径

在那之前，默认保留当前方案；只有在用户主动询问或明确安排部署收敛时，才重新推进这项改造。

### 3.4 执行 migration

```bash
COMPOSE_FILE=deploy/docker-compose.prod.yml ENV_FILE=deploy/.env.prod bash scripts/run-migrations.sh
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

浏览器侧校验：

- 打开 Web 域名
- 使用 `WEB_LOGIN_USERNAME` / `WEB_LOGIN_PASSWORD` 登录
- 打开 `任务池 -> 设置`，确认当前设备已出现在设备列表中
- 如果你是通过 HTTPS 域名访问，`WEB_SESSION_COOKIE_SECURE` 应保持 `true`
- 如果你当前只能通过 `http://<ip>:3080` 访问，必须把 `WEB_SESSION_COOKIE_SECURE=false` 写进 `deploy/.env.prod` 后再重建 `api` 容器，否则登录请求即使成功，cookie 也不会被浏览器持久化
- 上面这个开关只有在 `deploy/docker-compose.prod.yml` 已经把 `WEB_SESSION_COOKIE_SECURE` 传给 `api` 容器时才会生效；当前仓库主线已包含这项映射

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
3. 用 `DOCKER_BUILDKIT=0 docker build` 直接构建 `retodoscheduler-api:latest`、`retodoscheduler-web:latest`
4. 执行 `docker compose up -d --no-build --remove-orphans`
5. 跑 migration 并做健康检查

如果 workflow 日志里再次出现 `load local bake definitions`，说明服务器环境仍有其他入口绕过了仓库脚本，应该优先检查是否有人手工执行了 `docker compose build` 或 `docker compose up --build`。

## 7. 备份基线

每日本地 dump 示例：

```bash
mkdir -p /opt/retodo/backups
0 4 * * * docker exec retodo-db pg_dump -U retodo retodo | gzip > /opt/retodo/backups/retodo-$(date +\%F).sql.gz
```

## 8. 安全边界

- 对公网暴露前优先接入域名和 HTTPS 反向代理
- Web 生产环境应尽量保持同域部署，让浏览器直接用同源 session cookie 访问 `/v1/*`
- 默认生产 cookie 会带 `Secure`；只有在明确接受风险、且当前确实没有 HTTPS 时，才把 `WEB_SESSION_COOKIE_SECURE=false` 作为过渡方案
- 尽量限制 `8787` 的暴露范围
- 部署 key 使用最小权限用户，不要直接使用 root
- `docker compose` 项目名应显式固定，避免容器名和卷名漂移
- 服务器部署与 iOS 分发是两条不同流程，不应混用

恢复流程见 [recovery.md](recovery.md)。
