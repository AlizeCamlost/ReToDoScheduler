# 服务端部署

相关文档：

- [recovery.md](recovery.md)
- [client-sync.md](client-sync.md)

## 1. 适用范围

本指南用于部署 API + PostgreSQL，并作为 Web / iOS 同步的服务端基础。

## 2. 服务器前置条件

- Linux 服务器
- 已开放必要端口
- 已安装 Docker / Docker Compose / Git
- 已准备仓库目录
- 已准备 `deploy/.env.prod`

当前仓库里已有自动部署相关文件：

- `.github/workflows/deploy.yml`
- `scripts/server-auto-deploy.sh`

## 3. 拉取项目

```bash
cd /opt
sudo mkdir -p retodo
sudo chown $USER:$USER retodo
cd retodo
git clone <your-repo-url> .
```

## 4. 配置生产环境变量

```bash
cp deploy/.env.prod.example deploy/.env.prod
vi deploy/.env.prod
```

至少设置：

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `API_AUTH_TOKEN`

## 5. 构建并启动容器

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod up -d --build
```

## 6. 执行初始 migration

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /migrations/001_init.sql
```

如果 shell 没有导出 `.env.prod` 中的变量：

```bash
set -a
source deploy/.env.prod
set +a
```

然后重新执行 migration 命令。

## 7. 健康检查

```bash
curl http://127.0.0.1:8787/health
```

验证受保护接口：

```bash
curl -H "Authorization: Bearer $API_AUTH_TOKEN" http://127.0.0.1:8787/v1/tasks
```

## 8. 日常运维

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod logs -f api
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod restart api
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod ps
```

## 9. 自动部署概览

当前自动部署链路：

1. push 到 `main`
2. GitHub Actions 触发 deploy workflow
3. 通过 SSH 登录服务器
4. 执行 `scripts/server-auto-deploy.sh`

自动部署仍要求服务器已完成以下前置准备：

- 仓库目录已存在
- `deploy/.env.prod` 已配置
- 手动部署链路已验证可用
- GitHub Secrets / SSH key 已正确配置

更细的历史教程保留在 [archive/tutorial-github-auto-deploy-zh.md](archive/tutorial-github-auto-deploy-zh.md)。

## 10. 备份基线

每日本地 dump 示例：

```bash
mkdir -p /opt/retodo/backups
0 4 * * * docker exec retodo-db pg_dump -U retodo retodo | gzip > /opt/retodo/backups/retodo-$(date +\%F).sql.gz
```

## 11. 安全与经验注意事项

- 对公网暴露前优先接入域名 + HTTPS 反向代理
- 尽量限制 `8787` 暴露范围
- 部署 key 使用最小权限用户，不要直接使用 root
- `docker compose` 项目名应显式固定，避免容器名和卷名漂移
- 服务器部署与 iOS 分发是两条不同流程，不应混为一谈

恢复流程见 [recovery.md](recovery.md)。
