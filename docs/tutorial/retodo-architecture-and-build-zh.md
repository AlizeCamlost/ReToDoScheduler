# ReToDoScheduler 完整教学文档（中文）

## 1. 文档目标

这份文档面向“入门水平前端开发者”，目标是让你读完后能够：

1. 理解本项目当前架构与技术选型背后的取舍。
2. 理解每一层代码为什么这么写、解决了什么问题。
3. 能自己部署并排查 iOS/Web/Server 联调问题。
4. 不依赖 AI，能从零搭建一个同类型的 local-first 多端同步应用。

本项目当前阶段是 MVP：

1. iOS 和 Web 都能本地离线使用。
2. 通过 API 与 PostgreSQL 做简易跨端同步。
3. 冲突策略采用 LWW（最后写入覆盖）。

## 2. 先补基础概念（入门必读）

### 2.1 local-first 是什么

`local-first` 的核心是：

1. 用户操作优先写本地数据库（快、离线可用）。
2. 网络恢复后再和服务端同步。
3. 同步冲突通过规则解决（本项目是 LWW）。

为什么适合 ToDo：

1. 你经常在移动场景下使用，网络不可控。
2. 任务管理要求“随手记”，不能被网络阻塞。

### 2.2 REST API 是什么

REST 是一种 HTTP 接口组织方式：

1. `GET /v1/tasks`：读取任务。
2. `POST /v1/tasks/sync`：提交本地任务并拿回服务端合并结果。

你不需要先学完“复杂后端框架”，只要先掌握 HTTP + JSON + 路由就够了。

### 2.3 SQLite 和 PostgreSQL 的分工

1. SQLite：嵌入式本地数据库，适合手机离线写入。
2. PostgreSQL：服务端中心数据库，适合集中存储与多端同步。

这是“端本地 + 云中心”最常见且稳定的组合。

### 2.4 ATS（iOS 安全传输策略）

ATS 默认要求 HTTPS。用 HTTP 会被 iOS 拦截（错误码 `-1022`）。

当前项目为开发联调做了 ATS 放行，但长期要切 HTTPS（域名 + 证书）。

## 3. 架构总览

## 3.1 仓库结构（Monorepo）

项目根目录：`/Users/camlostshi/Documents/ReToDoScheduler`

1. `apps/mobile`：React Native + Expo 的 iOS 客户端。
2. `apps/web`：React + Vite 的 Web 客户端。
3. `services/api`：Fastify API。
4. `services/db`：PostgreSQL 迁移脚本。
5. `packages/core`：跨端共享的数据模型、默认值、轻量 NLP、打分工具。
6. `docs`：ADR、runbook、本教学文档。

Monorepo 价值：

1. 一套 TypeScript，前后端共享模型，减少重复定义。
2. 版本统一，协同改动可一次提交。

### 3.2 当前数据流

1. 用户在 iOS/Web 新增任务。
2. 先写本地存储（iOS SQLite），Web 端以内存态编辑并以服务器为唯一数据源。
3. 客户端调用 `POST /v1/tasks/sync` 上传本地任务列表。
4. 服务端按 LWW upsert 到 PostgreSQL。
5. 服务端返回合并后的任务列表。
6. 客户端再写回本地，完成收敛。

## 4. 选型取舍（为什么是这套）

### 4.1 客户端

选型：`React Native + Expo`（iOS） + `React + Vite`（Web） + `TypeScript`

取舍理由：

1. JS/TS 一套语言贯通，学习曲线低于 SwiftUI+React 双栈。
2. Expo 让原生门槛降低，必要时可下潜到 Xcode 原生工程。
3. Vite 启动快，开发体验好。

### 4.2 服务端

选型：`Fastify + PostgreSQL`

取舍理由：

1. Fastify 轻量、性能好、写法直接。
2. PostgreSQL 事务与 JSONB 能力强，适合后续规则扩展。

### 4.3 同步策略

当前选型：`全量列表同步 + LWW`

取舍理由：

1. 实现简单，能快速验证跨端闭环。
2. 单用户场景可接受。

已知限制：

1. 任务变多后全量同步会变慢。
2. 丢失“操作历史”语义，后续应升级为 `sync_ops + cursor` 增量同步。

## 5. 核心实现拆解

### 5.1 共享核心（`packages/core`）

关键文件：

1. `packages/core/src/types.ts`：任务模型与字段类型。
2. `packages/core/src/defaults.ts`：默认值与工厂方法 `makeTask`。
3. `packages/core/src/nlp.ts`：快速输入解析（时长、标签、关键词性质）。
4. `packages/core/src/scoring.ts`：任务打分占位（为调度器做基础）。

设计要点：

1. 任务字段里有 `minChunkMinutes` 与 `taskTraits`，为后续调度做约束。
2. `extJson` 预留扩展，避免每次新增规则都要改数据库表结构。

### 5.2 iOS 端（`apps/mobile`）

关键文件：

1. `apps/mobile/src/db.ts`：建库建表（`tasks` + `settings`）。
2. `apps/mobile/src/taskService.ts`：本地 CRUD + upsert + 设置项保存。
3. `apps/mobile/src/syncService.ts`：调用 `/v1/tasks/sync`。
4. `apps/mobile/App.tsx`：UI、同步按钮、轮询同步（服务器地址内置）。

工作机制：

1. 新增/完成/删除（归档）先写 SQLite。
2. 执行同步时，把本地任务列表 POST 到服务端。
3. 服务端返回合并后列表，本地再 upsert。

为什么“删除”做归档：

1. 物理删除会让跨端冲突难处理。
2. 归档是软删除，便于同步一致性。

### 5.3 Web 端（`apps/web`）

关键文件：

1. `apps/web/src/storage.ts`：会话级设备ID与导入导出辅助函数。
2. `apps/web/src/sync.ts`：pull/push API + LWW 合并。
3. `apps/web/src/App.tsx`：任务列表、拖拽、同步控制。

工作机制：

1. 本地改动先写内存态，然后立即 push 到服务端。
2. 每 7 秒 pull 一次，把服务端状态覆盖到页面，保证收敛。

### 5.4 API 端（`services/api`）

关键文件：

1. `services/api/src/index.ts`：Fastify 启动与 CORS。
2. `services/api/src/db.ts`：PostgreSQL 连接池。
3. `services/api/src/routes/tasks.ts`：`GET /v1/tasks` 与 `POST /v1/tasks/sync`。

`POST /v1/tasks/sync` 做了什么：

1. 校验请求体。
2. 逐条 `INSERT ... ON CONFLICT(id) DO UPDATE`。
3. 更新条件是 `EXCLUDED.updated_at > tasks.updated_at`（LWW）。
4. 返回服务端当前完整任务列表。

### 5.5 数据库端（`services/db`）

关键文件：

1. `services/db/migrations/001_init.sql`

定义了任务、子任务、时间窗、学习事件、同步日志等基础表。

当前同步主用 `tasks` 表；其他表为后续阶段预留。

## 6. 你关心的“部署命令都做了什么”

### 6.1 本地开发命令

在项目根执行：

1. `npm install`
作用：安装 monorepo 所有依赖。

2. `npm run lint`
作用：TypeScript 静态检查（core/web/mobile/api）。

3. `npm run build`
作用：构建 web 和 api，验证可发布产物。

4. `npm run ios:dev`
作用：一键启动 iOS 开发环境（脚本见 `scripts/ios-dev.sh`）。

5. `npm run ios:prepare`
作用：重建 iOS 原生工程并打开 Xcode。

### 6.2 iOS 原生构建相关命令

1. `npm --prefix apps/mobile run prebuild:ios`
作用：由 Expo 生成/刷新 `apps/mobile/ios` 原生工程。

2. `pod install`（通常 prebuild 自动触发）
作用：安装 iOS 原生依赖到 `ios/Pods`。

3. Xcode `Cmd + R`
作用：编译并安装到真机。

### 6.3 服务器部署命令

参考：`docs/runbook/server-deploy.md`

核心步骤：

1. `docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env.prod up -d --build`
作用：构建并启动 API + PostgreSQL。

2. `docker compose ... exec -T db psql ... -f /migrations/001_init.sql`
作用：执行数据库初始化迁移。

3. `curl http://127.0.0.1:8787/health`
作用：确认 API 存活。

你也可以直接：

1. `bash scripts/deploy-prod.sh`
作用：把上面步骤串成一键脚本。

## 7. ATS/HTTP 的关键说明

你遇到的 `-1022` 本质是 iOS 拒绝明文 HTTP。

当前项目为开发联调做了两层处理：

1. 全局开发放行（`NSAllowsArbitraryLoads`）。
2. 对目标 IP 的 `NSExceptionDomains` 显式放行。

相关文件：

1. `apps/mobile/app.json`
2. `apps/mobile/ios/ReToDoScheduler/Info.plist`

注意：生产必须切 HTTPS，不建议长期保持全局 HTTP 放行。

## 8. 从零复刻一个同类项目（无 AI 的执行路径）

你可以按这 12 步独立完成：

1. 初始化 monorepo（`apps/mobile`, `apps/web`, `services/api`, `packages/core`）。
2. 在 `core` 定义统一 `Task` 类型。
3. 先做 iOS 本地 SQLite CRUD，保证离线可用。
4. 再做 Web 基础 CRUD（以内存态操作 + 服务端同步）。
5. 搭 API：先 `health`，再 `tasks` 路由。
6. 接 PostgreSQL，写 `tasks` 表。
7. 实现 `/v1/tasks/sync` + `ON CONFLICT` + `updated_at` 条件。
8. 客户端做“本地写 + push + pull”。
9. 加固定服务器地址配置、Bearer Token 与设备 ID。
10. 处理删除策略（先软删除/归档）。
11. Docker 化 API+DB，写迁移脚本。
12. 写 runbook 和一键脚本，固化日常操作。

通过这个路径，你能掌握真实工程里最重要的能力：

1. 数据模型抽象能力。
2. 前后端联调能力。
3. 移动端原生构建与签名能力。
4. 部署与运维基础能力。

## 9. 当前实现的边界与下一步

当前边界：

1. 同步是“全量列表”，不是增量。
2. 冲突只用 LWW，不做字段级或字符级合并。
3. 安全还在开发态（HTTP 放行）。

建议下一步（按优先级）：

1. 上 HTTPS（域名 + 反向代理 + 证书）。
2. 同步升级为 `sync_ops + cursor`。
3. 增加 token 轮换策略与设备级吊销能力。
4. 增加自动备份与恢复演练。

## 10. 你应该重点阅读哪些源码

建议阅读顺序：

1. `packages/core/src/types.ts`
2. `apps/mobile/src/taskService.ts`
3. `apps/web/src/sync.ts`
4. `services/api/src/routes/tasks.ts`
5. `services/db/migrations/001_init.sql`

这五个文件能帮你理解“模型 -> 客户端状态 -> 同步协议 -> 服务端合并 -> 持久化”的完整闭环。

## 11. 实操练习（建议你亲自做）

练习 1：新增字段

1. 给 Task 新增 `energyLevel`。
2. 修改 core 类型、mobile 表结构、api upsert、web 展示。
3. 验证 iOS 改动能同步到 web。

练习 2：把轮询间隔改为可配置

1. 在 `settings` 增加 `sync_interval_ms`。
2. iOS/Web 从配置读取轮询间隔。

练习 3：实现“仅拉取最近 24 小时变更”

1. API 增加 `updatedAfter` 查询参数。
2. Web/iOS 维护 `lastPulledAt`。

做完这三项，你就能独立推进 Phase 2/3 的工程化演进。

## 12. 维护约定

后续只要出现以下变化，本教学文档必须同步更新：

1. 架构变化（例如从全量同步改为增量同步）。
2. 启动命令变化（iOS/Web/API）。
3. 部署方式变化（compose、CI/CD、环境变量）。
4. 安全策略变化（ATS、HTTP/HTTPS、鉴权）。
