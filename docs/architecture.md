# 系统架构

相关文档：

- [product-model.md](product-model.md)
- [scheduling-model.md](scheduling-model.md)
- [adr/0001-monorepo-and-stack.md](adr/0001-monorepo-and-stack.md)
- [adr/0002-local-first-sync.md](adr/0002-local-first-sync.md)

## 1. 系统定位

ReToDoScheduler 是一个面向 iPhone + Web 的 local-first 任务池与动态调度系统。

系统有两个稳定目标：

1. 任务录入本身就能完成认知卸载。
2. 在当前任务池和可用时间约束下，动态派生“现在到未来一段时间该怎么安排”的调度视图。

## 2. 分层结构

```text
apps/web + apps/mobile
        ↓
    packages/core
        ↓
   services/api
        ↓
    services/db
```

各层职责：

- `apps/web`: 浏览器端任务管理与调度视图
- `apps/mobile`: iPhone 端本地任务管理、同步与调度视图
- `packages/core`: 共享任务模型、默认值、快速输入解析、调度器与前端 view-model 逻辑
- `services/api`: 认证、同步、持久化边界
- `services/db`: PostgreSQL schema 与迁移

在概念层面，仓库中仍保留 `Norn` / `Kairos` 作为模块边界：

- `Norn`: 任务池维护层
- `Kairos`: 动态调度层

但在代码中的具体类型、函数和产品文案中，统一使用朴素语义化命名。

## 3. 仓库模块图

### packages/core

- 拥有 canonical task/time types
- 拥有 `makeTask`、默认值、快速输入解析
- 拥有动态调度器与共享前端派生逻辑

### apps/web

- 以服务端同步为主的数据入口
- 展示任务池、时间模板和动态调度视图

### apps/mobile

- iPhone-first 入口
- 使用 SQLite 做本地持久化
- 使用与 Web 相同的共享任务模型和调度器

### services/api

- 提供 `/health`、`/v1/tasks`、`/v1/tasks/sync`
- 以 Bearer token 保护 `/v1/*`
- 当前同步策略采用全量列表同步 + LWW

### services/db

- 管理 PostgreSQL migration
- 保持 schema 演进与 API 路由解耦

## 4. 当前数据流

### 任务录入与同步

1. 用户在 Web 或 iOS 新增 / 编辑 / 完成 / 归档任务
2. 客户端先更新本地状态
3. 客户端调用 `/v1/tasks/sync`
4. 服务端按 `updatedAt` 做 LWW upsert
5. 服务端返回当前任务集合
6. 客户端收敛到服务端返回结果

### 调度视图生成

1. 客户端拿到当前任务池
2. 结合时间模板和观察窗口 `horizon`
3. 在 `packages/core` 中调用调度器
4. 派生出时间块、任务序列和预警

调度视图是派生结果，不是单独维护的一份静态真相表。

## 5. 设计原则

- local-first：用户操作不应被网络阻塞
- 单一真相源：当前规范文档只保留一份活动版本
- 渐进增强：首轮实现先覆盖核心任务池与调度模型
- 共享逻辑优先：任务模型、调度器、前端 view-model 尽量下沉到 `packages/core`
- 历史文档归档：旧教程、旧设计稿、阶段性记录不再与活动规范并列

## 6. 运维边界

部署与联调的当前边界：

- iOS 启动与真机安装见 [ios.md](ios.md)
- 客户端同步配置与排障见 [client-sync.md](client-sync.md)
- 服务端部署见 [server-deploy.md](server-deploy.md)
- 恢复流程见 [recovery.md](recovery.md)

## 7. 当前已知取舍

- 当前同步仍是全量列表 + LWW，实现简单，但不保留操作语义
- Web 和 iOS 已共享核心任务与调度模型，但渲染层仍保留平台差异
- 当前调度器是启发式滚动重算，不追求一次性全局最优
- 复杂并行、资源模型、学习型比较器仍是后续增强项
