# ReToDoScheduler 开发部署 Todo Handbook

> 状态标记：⬜ 未开始 | 🔲 进行中 | ✅ 已完成 | ⏭️ 跳过
>
> 最后更新：2026-03-08（Phase 2 完成）

---

## 环境信息

| 项目 | 值 |
|------|-----|
| **远程服务器** | |
| 服务器 OS | OpenCloudOS 9.4（RHEL 系，包管理 `dnf`） |
| 服务器项目路径 | `/root/documents/retodo/ReToDoScheduler` |
| 服务器 SSH 端口 | **2222**（非默认 22） |
| 服务器 Docker | 29.2.1（已安装，含 Compose V2） |
| 宿主机 Nginx | 已运行，反向代理 80 → Docker 3080；同时服务 `camloshi.art` → 5173 |
| 域名 | 审批中，预计 ~2026-03-11 到位；到位前用 HTTP + 公网 IP |
| GitHub 仓库 | Private，`https://github.com/AlizeCamlost/ReToDoScheduler.git` |
| 服务器 GitHub 访问 | Deploy Key（SSH，只读） |
| **本地开发机 (Mac)** | |
| Node.js | v22.13.0 |
| npm | 10.9.2 |
| Docker Desktop | 29.2.1 + Compose v5.0.2（通过 `brew install --cask docker` 安装） |
| Apple Developer | 已有账号 |

---

## Phase 0：服务器基础准备（一次性） ✅

> 目标：让远程服务器具备接收自动部署的能力。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 0.1 | 服务器安装 Docker + Docker Compose | ⏭️ | Docker 29.2.1 已安装 |
| 0.2 | 确认服务器 Git 已安装 | ✅ | |
| 0.3 | 为 Private 仓库配置服务器访问权限 | ✅ | Deploy Key（SSH 方式） |
| 0.4 | 在服务器上 clone 仓库 | ✅ | `/root/documents/retodo/ReToDoScheduler` |
| 0.5 | 在服务器创建 `deploy/.env.prod` | ✅ | |
| 0.6 | 确保服务器防火墙放行 80 端口 | ✅ | 云控制台安全组 |
| 0.6b | 宿主机 Nginx 反向代理配置 | ✅ | `/etc/nginx/conf.d/retodo.conf` → `proxy_pass 127.0.0.1:3080` |
| 0.7 | 手动执行一次部署脚本 | ✅ | |
| 0.8 | 验证 API 健康检查 | ✅ | `curl http://127.0.0.1:3080/health` → ok |
| 0.9 | 验证 Web 页面可通过公网 IP 访问 | ✅ | |

---

## Phase 1：趟通 GitHub Actions 自动部署 ✅

> 目标：push 到 `main` 后，GitHub Actions 自动 SSH 到服务器执行部署脚本，全链路跑通。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 1.1 | 本地生成部署专用 SSH 密钥对 | ✅ | `~/.ssh/retodo_deploy` |
| 1.2 | 将公钥添加到服务器 `authorized_keys` | ✅ | |
| 1.3 | 在 GitHub 仓库配置 Actions Secrets | ✅ | `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_PATH`, `DEPLOY_SSH_KEY`, `DEPLOY_PORT=2222` |
| 1.4 | push commit 触发 deploy workflow | ✅ | |
| 1.5 | GitHub Actions 页面确认绿色 | ✅ | 经过数次调试后成功 |
| 1.6 | 服务器容器运行正常 | ✅ | |
| 1.7 | 外部浏览器访问 Web 正常 | ✅ | |
| 1.8 | API 可达 | ✅ | |

**Phase 1 完成标志**：push 到 main → Actions 绿色 → 服务器自动更新 → Web/API 外部可访问 ✅

---

## Phase 2：搭建本地开发环境与工作流 ✅

> 目标：在本地能完整运行 DB + API + Web，快速迭代调试。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 2.0 | 安装 Docker Desktop | ✅ | `brew install --cask docker`，Docker 29.2.1 + Compose v5.0.2 |
| 2.1 | 启动本地 PostgreSQL（Docker） | ✅ | `npm run dev:db:up` |
| 2.2 | 初始化本地数据库（执行 migration） | ✅ | `docker exec -i retodo-db psql -U retodo -d retodo < services/db/migrations/001_init.sql` |
| 2.3 | 启动本地 API 服务 | ✅ | 宿主机运行，需传环境变量（见下方启动命令） |
| 2.4 | 验证本地 API 健康检查 | ✅ | `curl http://localhost:8787/health` → `{"ok":true}` |
| 2.5 | 配置 Web 环境变量 | ✅ | 已创建 `apps/web/.env`（基于 `.env.example`） |
| 2.6 | 启动本地 Web 服务 | ✅ | `npm run dev:web` → `http://localhost:5173` |
| 2.7 | 浏览器验证页面渲染 + CRUD 联调 | ✅ | Web ↔ API ↔ DB 联调通过 |

**Phase 2 完成标志**：本地 Web ↔ API ↔ DB 联调通过，CRUD 和 sync 正常工作。 ✅

---

## Phase 3：功能开发 → 本地验证 → 推送部署

> 目标：建立日常开发节奏——本地写代码、调试、验证，确认 OK 后 push 到 main 自动部署。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 3.1 | 确定 Web 端第一批要开发的功能清单 | ⬜ | 根据产品需求细化 |
| 3.2 | 本地开发功能 | ⬜ | 在 feature 分支开发 |
| 3.3 | 本地运行 lint + build 确认无错误 | ⬜ | `npm run lint && npm run build` |
| 3.4 | 本地 Web 端手动验证功能 | ⬜ | 在浏览器中操作确认 |
| 3.5 | merge 到 main 并 push | ⬜ | 自动触发 GitHub Actions 部署 |
| 3.6 | 确认 Actions 执行成功，远程服务器已更新 | ⬜ | |
| 3.7 | 在远程地址验证功能上线效果 | ⬜ | |

**日常开发循环**：`feature 分支开发` → `本地验证` → `merge main` → `push` → `自动部署` → `远程验证`

---

## Phase 4：iOS 移动端开发与部署

> 目标：在 Web 端功能稳定后，启动 iOS 移动端开发。移动端复用 `@retodo/core` 共享逻辑，使用本地 SQLite + 云端 sync。

### 4A：本地移动端开发环境

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 4A.1 | 确认 Xcode 已安装且版本满足要求 | ⬜ | |
| 4A.2 | `npm run ios:prepare` 生成/刷新原生工程 | ⬜ | Expo prebuild + pod install |
| 4A.3 | 启动本地 API 服务（供移动端联调） | ⬜ | `npm run dev:api`，移动端需能访问本地 IP |
| 4A.4 | 启动 Metro 并在模拟器/真机运行 | ⬜ | `npm run ios:dev` 或 Xcode `Cmd+R` |
| 4A.5 | 验证移动端 CRUD 功能（本地 SQLite） | ⬜ | |
| 4A.6 | 验证移动端与本地 API 的 sync 功能 | ⬜ | 注意 ATS/HTTP 设置 |

### 4B：移动端与远程服务器联调

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 4B.1 | 配置移动端指向远程 API 地址 | ⬜ | `EXPO_PUBLIC_API_BASE_URL` |
| 4B.2 | **(重要)** 远程服务器上 HTTPS（域名 + 证书） | ⬜ | iOS 生产环境强制 HTTPS |
| 4B.3 | 验证移动端与远程 API 的 sync 功能 | ⬜ | |
| 4B.4 | 跨端验证：Web ↔ 移动端 sync | ⬜ | |

### 4C：移动端分发

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 4C.1 | 配置 Apple Developer 证书与描述文件 | ⬜ | |
| 4C.2 | TestFlight 内测分发 | ⬜ | |
| 4C.3 | （可选）App Store 正式上架 | ⬜ | |

---

## 跨阶段待办 / 持续改进

| # | 任务 | 状态 | 优先级 | 备注 |
|---|------|------|--------|------|
| X.1 | CI 补全：扩展 `ci.yml` 覆盖 web/api 的 lint + build | ⬜ | 高 | 当前 CI 仅测 `packages/core` |
| X.2 | 让 deploy workflow 依赖 CI 通过后才执行 | ⬜ | 高 | 避免有编译错误的代码被部署到生产 |
| X.3 | HTTPS 部署（域名 + Let's Encrypt + Nginx 反向代理） | ⬜ | 高 | 域名预计 ~03-11 到位；iOS 生产必须 HTTPS；推荐在 Phase 4B 之前完成 |
| X.4 | 数据库 migration 运行器改造 | ⬜ | 中 | 当前脚本硬编码 `001_init.sql`，后续新增 migration 需改为按序执行所有 `.sql` |
| X.5 | 编写自动化测试 | ⬜ | 中 | 当前所有包的 test 脚本都是 `echo "No tests yet"` |
| X.6 | 数据库备份与恢复策略 | ⬜ | 中 | `pg_dump` 定时备份 |
| X.7 | 监控与告警 | ⬜ | 低 | 服务器资源监控、API 可用性告警 |

---

## 经验教训（Phase 0 & 1 踩坑记录）

> 这些是在趟通部署链路时遇到的实际问题和解决方案，供后续排查参考。

### 1. 端口冲突：宿主机 Nginx 占用 80 端口
- **现象**：Docker `retodo-web` 容器试图绑定 80 端口失败
- **原因**：服务器上已有宿主机 Nginx 运行，占用 80 端口（同时服务 `camloshi.art` 等站点）
- **解决**：Docker 容器改为映射到 3080 端口，宿主机 Nginx 添加 `/etc/nginx/conf.d/retodo.conf` 反向代理到 3080
- **修改文件**：`deploy/docker-compose.prod.yml`（`ports: "3080:80"`），API 改为 `expose: "8787"`（不对外暴露）

### 2. 残留容器占用端口
- **现象**：`retodo-api-dev`（之前用开发 compose 启动的）占着 8787 端口
- **解决**：`docker rm -f retodo-api-dev` 清理残留容器
- **教训**：部署前先 `docker ps -a` 检查是否有旧容器残留

### 3. SSH 端口不是默认 22
- **现象**：GitHub Actions SSH 连接 `connection refused`
- **原因**：服务器 SSH 端口是 2222，不是 22
- **解决**：在 GitHub Secrets 中添加 `DEPLOY_PORT=2222`
- **排查方式**：`ssh -v <server-ip> 2>&1 | grep "Connecting to"`

### 4. 部署脚本自更新的 bash 陷阱
- **现象**：`server-auto-deploy.sh` 通过 `git pull` 更新了自身，但本次运行仍执行旧逻辑
- **原因**：bash 在执行前已将脚本加载到内存，`git pull` 只更新磁盘文件
- **解决**：接受这个限制——脚本的改动需要两次部署才能生效（第一次更新文件，第二次执行新版本）
- **教训**：对部署脚本的修改，push 后需触发两次 workflow（或者第一次手动 re-run）

### 5. API 容器启动延迟导致健康检查 502
- **现象**：容器启动后立即健康检查返回 502 Bad Gateway
- **原因**：API 容器重建后需要几秒钟才能就绪
- **解决**：健康检查改为重试机制（最多 10 次，每次间隔 3 秒）
- **修改文件**：`scripts/server-auto-deploy.sh`

### 6. Private 仓库需要 Deploy Key
- **原因**：Private 仓库无法匿名 clone/pull
- **解决**：在服务器生成 SSH Key → 添加为 GitHub 仓库的 Deploy Key（只读）→ 配置 `~/.ssh/config`
- **注意**：这个 key 是给服务器**拉代码**用的，跟 GitHub Actions **SSH 登录服务器**的 key 是两把不同的钥匙

### Phase 2 踩坑与经验

### 7. Cursor 终端启动的进程 vs Docker 容器的生命周期
- **API 和 Web 开发服务器**（`tsx watch`、`vite`）是 Cursor 内置终端的子进程，**关闭 Cursor 时自动终止**
- **Docker Desktop 和 retodo-db 容器**是独立于 Cursor 的，不会随 Cursor 关闭而停止
- retodo-db 容器的重启策略是 `unless-stopped`，**只要 Docker Desktop 在运行就会保持运行**，重启电脑后也会自动拉起
- **收工建议**：`npm run dev:db:down` 停掉数据库容器，不用 Docker 时退出 Docker Desktop（释放 ~1–2 GB 内存）

### 8. 本地 API 需要手动传环境变量
- 本地 API 在宿主机运行（不在 Docker 中），需要通过命令行传入 `DATABASE_URL` 和 `API_AUTH_TOKEN`
- `docker-compose.yml` 中有一个 `api` 服务定义（容器化方式），但本地开发推荐宿主机直接运行以获得 hot-reload
- Web 端的 `VITE_API_AUTH_TOKEN` 必须与 API 端的 `API_AUTH_TOKEN` 一致，否则请求会被 401 拒绝

---

## 当前架构拓扑

### 远程服务器（生产）

```
[你的 Mac] --push--> [GitHub] --SSH (port 2222)--> [远程服务器]
                                                        |
                                                  server-auto-deploy.sh
                                                        |
                                                   git pull + docker compose up
                                                        |
                                        +---------------+---------------+
                                        |               |               |
                                  [retodo-db]     [retodo-api]    [retodo-web]
                                  PostgreSQL      Fastify:8787    Nginx:80→3080
                                   (容器内)        (expose only)   (映射到宿主机3080)
                                                        |
                                                        |
                                               [宿主机 Nginx :80]
                                               proxy_pass → 127.0.0.1:3080
                                                        |
                                                  [公网 IP :80]
                                                        |
                                                   用户浏览器访问
```

### 本地开发环境

```
[Docker Desktop]
      |
[retodo-db 容器]  ← PostgreSQL:5432（Docker，数据持久化在 volume）
      |
      |  DATABASE_URL=postgresql://retodo:retodo_dev_password@127.0.0.1:5432/retodo
      ↓
[API 开发服务器]  ← tsx watch :8787（宿主机 Node 进程，Cursor 子进程）
      |
      |  VITE_API_BASE_URL=http://127.0.0.1:8787
      ↓
[Web 开发服务器]  ← Vite :5173（宿主机 Node 进程，Cursor 子进程）
      |
      ↓
  浏览器 http://localhost:5173
```

---

## 认知提醒

### 1. 移动端部署 ≠ 服务器部署
push 到 GitHub 触发的自动部署只影响**服务端**（API + DB + Web）。iOS App 是独立的分发流程：
- 开发阶段：通过 USB/Xcode 安装到真机
- 内测阶段：通过 TestFlight 分发
- 正式阶段：通过 App Store 上架

两者的更新节奏是独立的。服务端可以随时部署，App 需要走 Apple 审核。

### 2. HTTPS 不是可选的
iOS ATS（App Transport Security）在生产环境**强制 HTTPS**。当前项目为开发做了 HTTP 放行（`NSAllowsArbitraryLoads`），但上线前必须：
1. 为服务器绑定域名（预计 ~03-11 到位）
2. 配置 SSL 证书（推荐 Let's Encrypt 免费证书）
3. Nginx 反向代理 443 → API

域名到位前可先用 HTTP + 公网 IP 完成 Phase 0~3。域名到位后立即配 HTTPS，在 Phase 4B 之前完成。

### 3. CI 应该保护 deploy
当前 `deploy.yml` 和 `ci.yml` 是独立触发的——即使 CI 失败，deploy 仍会执行。建议将 deploy 设为依赖 CI 成功，避免将有问题的代码部署到生产。

### 4. Migration 管理需升级
当前部署脚本硬编码执行 `001_init.sql`。随着开发推进，新增的表结构变更需要新的 migration 文件（`002_xxx.sql`, `003_xxx.sql`...），部署脚本需要改为按序执行所有未运行的 migration。

---

## 本地开发环境启动 / 关闭速查

### 启动（每次开发前）

```bash
# 0. 确保 Docker Desktop 已打开

# 1. 启动数据库
npm run dev:db:up

# 2. 启动 API（终端 1）
DATABASE_URL="postgresql://retodo:retodo_dev_password@127.0.0.1:5432/retodo" \
API_AUTH_TOKEN="retodo-dev-token-change-me" \
npm run dev:api

# 3. 启动 Web（终端 2）
npm run dev:web

# 首次初始化数据库时才需要（后续不需要重复执行）：
# docker exec -i retodo-db psql -U retodo -d retodo < services/db/migrations/001_init.sql
```

### 关闭（收工时）

```bash
# Ctrl+C 停止 API 和 Web 开发服务器（或关闭 Cursor 自动终止）
# 停止数据库容器（数据保留在 Docker volume 中）
npm run dev:db:down
# 可选：退出 Docker Desktop 释放 ~1-2 GB 内存
```

### 本地开发凭据（开发用，非敏感）

| 变量 | 值 |
|------|-----|
| `DATABASE_URL` | `postgresql://retodo:retodo_dev_password@127.0.0.1:5432/retodo` |
| `API_AUTH_TOKEN` | `retodo-dev-token-change-me` |
| `VITE_API_BASE_URL` | `http://127.0.0.1:8787` |
| `VITE_API_AUTH_TOKEN` | `retodo-dev-token-change-me`（需与 API_AUTH_TOKEN 一致） |

Web 端环境变量已配置在 `apps/web/.env` 中，API 端通过命令行传入。

---

## 下一步（新 session 接续）

1. **Phase 3**：功能开发 → 本地验证 → 推送部署
   - 确定 Web 端第一批要开发的功能清单
   - 在 feature 分支开发 → 本地验证 → merge main → push → 自动部署 → 远程验证
2. 本地开发环境已就绪，启动命令见上方速查表
3. 关注域名审批进度（预计 ~03-11），到位后立即配置 HTTPS（Phase 4B 前置依赖）
