# ReToDoScheduler 开发部署 Todo Handbook

> 状态标记：⬜ 未开始 | 🔲 进行中 | ✅ 已完成 | ⏭️ 跳过
>
> 最后更新：2026-03-08

---

## 环境信息

| 项目 | 值 |
|------|-----|
| 服务器 OS | OpenCloudOS 9.4（RHEL 系，包管理 `dnf`） |
| Docker | 29.2.1（已安装，含 Compose V2） |
| 域名 | 审批中，预计 ~2026-03-11 到位；到位前用 HTTP + 公网 IP |
| GitHub 仓库 | Private（服务器 clone 需配 Deploy Key 或 PAT） |
| Apple Developer | 已有账号 |

---

## Phase 0：服务器基础准备（一次性）

> 目标：让远程服务器具备接收自动部署的能力。这是所有后续 Phase 的前提。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 0.1 | 服务器安装 Docker + Docker Compose | ⏭️ | Docker 29.2.1 已安装 |
| 0.2 | 确认服务器 Git 已安装 | ⬜ | `git --version`，OpenCloudOS 通常预装；若无则 `dnf install git` |
| 0.3 | 为 Private 仓库配置服务器访问权限 | ⬜ | 方式二选一（推荐方案 A）：**A)** 在服务器生成 SSH Key → 添加为 GitHub 仓库的 Deploy Key；**B)** 使用 GitHub PAT + HTTPS clone |
| 0.4 | 在服务器上 clone 仓库到目标目录 | ⬜ | `git clone git@github.com:<user>/ReToDoScheduler.git /opt/retodo`（SSH 方式） |
| 0.5 | 在服务器创建 `deploy/.env.prod`，填写生产环境变量 | ✅ | |
| 0.6 | 确保服务器防火墙放行 80 端口 | ✅ | 云控制台安全组 |
| 0.6b | 宿主机 Nginx 反向代理配置 | ✅ | `/etc/nginx/conf.d/retodo.conf` → `proxy_pass 127.0.0.1:3080`；原 `nginx.conf` 默认 server 已注释（备份 `.bak`） |
| 0.7 | 在服务器手动执行一次部署脚本，确认基础链路通 | ✅ | |
| 0.8 | 验证 API 健康检查 | ✅ | `curl http://127.0.0.1:3080/health` → ok |
| 0.9 | 验证 Web 页面可通过 `http://<server-ip>` 访问 | ✅ | |

---

## Phase 1：趟通 GitHub Actions 自动部署

> 目标：push 到 `main` 后，GitHub Actions 自动 SSH 到服务器执行部署脚本，全链路跑通。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 1.1 | 本地生成部署专用 SSH 密钥对 | ⬜ | `ssh-keygen -t ed25519 -C "retodo-deploy" -f ~/.ssh/retodo_deploy` |
| 1.2 | 将公钥添加到服务器用户的 `authorized_keys` | ⬜ | 见 `docs/tutorial/github-auto-deploy-zh.md` 第 3 节 |
| 1.3 | 在 GitHub 仓库配置 Actions Secrets/Variables | ⬜ | `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_PATH`, `DEPLOY_SSH_KEY`（私钥，必须用 Secret）, `DEPLOY_PORT`（可选，默认 22） |
| 1.4 | push 一个测试 commit 到 `main`，触发 deploy workflow | ⬜ | |
| 1.5 | 在 GitHub Actions 页面确认 workflow 执行成功（绿色） | ⬜ | |
| 1.6 | SSH 到服务器验证容器运行状态 | ⬜ | `docker compose -f deploy/docker-compose.prod.yml ps` |
| 1.7 | 从外部浏览器访问 `http://<server-ip>` 确认 Web 可用 | ⬜ | |
| 1.8 | 从外部验证 API 可达 | ⬜ | `curl http://<server-ip>/health` |

**Phase 1 完成标志**：push 到 main → Actions 绿色 → 服务器自动更新 → Web/API 外部可访问。

---

## Phase 2：搭建本地开发环境与工作流

> 目标：在本地能完整运行 DB + API + Web，快速迭代调试。

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 2.1 | 启动本地 PostgreSQL（Docker） | ⬜ | `npm run dev:db:up` → `docker compose up -d db` |
| 2.2 | 初始化本地数据库（执行 migration） | ⬜ | `docker exec -i retodo-db psql -U retodo -d retodo < services/db/migrations/001_init.sql` |
| 2.3 | 启动本地 API 服务 | ⬜ | `npm run dev:api` (端口 8787) |
| 2.4 | 验证本地 API 健康检查 | ⬜ | `curl http://localhost:8787/health` |
| 2.5 | 启动本地 Web 服务 | ⬜ | `npm run dev:web` (Vite dev server) |
| 2.6 | 浏览器打开 Web 页面，确认页面渲染正常 | ⬜ | |
| 2.7 | 在 Web 上新增/编辑/完成任务，验证与 API+DB 的联动 | ⬜ | |
| 2.8 | 确认 Web 的环境变量配置正确 | ⬜ | `VITE_API_BASE_URL` (本地默认空即可), `VITE_API_AUTH_TOKEN` |

**Phase 2 完成标志**：本地 Web ↔ API ↔ DB 联调通过，CRUD 和 sync 正常工作。

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
| 4B.2 | **(重要)** 远程服务器上 HTTPS（域名 + 证书） | ⬜ | iOS 生产环境强制 HTTPS，见下方说明 |
| 4B.3 | 验证移动端与远程 API 的 sync 功能 | ⬜ | |
| 4B.4 | 跨端验证：Web 创建任务 → 移动端 sync 可见（反向亦然） | ⬜ | |

### 4C：移动端分发

| # | 任务 | 状态 | 备注 |
|---|------|------|------|
| 4C.1 | 配置 Apple Developer 证书与描述文件 | ⬜ | |
| 4C.2 | TestFlight 内测分发 | ⬜ | |
| 4C.3 | （可选）App Store 正式上架 | ⬜ | |

---

## 跨阶段待办 / 持续改进

> 这些任务不属于某个特定 Phase，但会在开发过程中逐步落实。

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

## 待确认 / 补充

| # | 问题 | 状态 |
|---|------|------|
| Q.1 | 服务器上准备用什么路径存放项目？（默认建议 `/opt/retodo`） | 待确认 |
| Q.2 | 服务器 SSH 端口是默认 22 还是自定义？ | 待确认 |
| Q.3 | 域名到位后，是否需要协助配置 HTTPS（Let's Encrypt + Nginx）？ | 域名审批中 |

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
