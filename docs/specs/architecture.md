# 系统架构

相关文档：

- [product-model.md](product-model.md)
- [scheduling-model.md](scheduling-model.md)
- [../adr/0001-monorepo-and-stack.md](../adr/0001-monorepo-and-stack.md)
- [../adr/0002-local-first-sync.md](../adr/0002-local-first-sync.md)

## 1. 作用范围

本文档只回答四件事：

- 运行时由哪些层组成
- 仓库里每层各自负责什么
- 数据如何在双端、本地和服务端之间流动
- 改动时哪些地方必须保持双端语义一致

产品语义见 [product-model.md](product-model.md)。调度问题的形式化定义见 [scheduling-model.md](scheduling-model.md)。

## 2. 运行时结构

```text
apps/web + apps/mobile
        ↓
    packages/core
        ↓
   services/api
        ↓
    services/db
```

概念层仍保留两条边界：

- `Norn`: 任务池维护层
- `Kairos`: 动态调度层

但代码与产品文案统一使用直接命名的实体，如 `Task`、`TaskStep`、`TaskGraph`、`TimeTemplate`、`ScheduleView`。

## 3. 仓库职责

### 3.1 `packages/core`

- 维护共享的任务、时间模板、调度视图类型
- 维护默认值、归一化和快速输入辅助
- 维护 TypeScript 版调度器与比较器接口
- 作为 Web 端语义真相源

### 3.2 `apps/web`

- 浏览器端任务池、时间模板、调度视图 UI
- 以服务端同步为主要远端入口
- 对外呈现 `packages/core` 的派生结果

### 3.3 `apps/mobile`

- SwiftUI 原生 iPhone 客户端
- 本地 JSON 持久化、设置存储、同步入口
- 保留一份 Swift 调度实现，但语义必须对齐 [scheduling-model.md](scheduling-model.md)

### 3.4 `services/api`

- 对外提供 `/health`、`/v1/tasks`、`/v1/tasks/sync`
- 以 Bearer token 作为当前 MVP 认证边界
- 负责同步收敛和持久化出入口

### 3.5 `services/db`

- 维护 PostgreSQL schema 和 migration
- 保持数据库演进与 API 实现解耦

## 4. 数据流

### 4.1 任务录入与同步

1. 用户在 Web 或 iPhone 创建、编辑、完成或归档任务。
2. 客户端先更新本地状态。
3. 客户端向 `/v1/tasks/sync` 发起同步。
4. 服务端按 `updatedAt` 做 LWW 收敛。
5. 服务端返回当前任务集合。
6. 客户端收敛到服务端返回结果。

### 4.2 调度视图生成

1. 客户端拿到当前任务池。
2. 客户端结合时间模板和观察窗口 `horizon`。
3. 调用本地调度器生成 `ScheduleView`。
4. UI 渲染时间块、任务序列、未排入项和预警。

`ScheduleView` 是派生数据，不是单独维护的静态主表。

## 5. 双端对齐约束

- 改任务字段时，必须同时检查 Web `TaskEditModal` 和 iOS `TaskEditorSheet`。
- 改时间模板结构时，必须同时检查 Web 的模板存取逻辑和 iOS `TaskRepository` 的读写逻辑。
- 改调度展示语义时，必须同时检查 Web `SchedulePanel` 和 iOS `ScheduleSection`。
- 改同步协议时，必须同时检查 Web `features/sync/data/taskSync.ts`、iOS `Shared/Services/SyncService.swift` 和 API 路由。
- 只做单端的视觉样式微调可以分开改；只要涉及字段、流程、信息架构或调度语义，就必须按双端改动处理。

## 6. 当前边界

- 当前同步仍是全量列表 + LWW，不保留操作级历史。
- Web 以 `packages/core` 为共享语义实现；iOS 保留镜像实现，但不得自行发明新语义。
- 当前调度器是启发式滚动重算，不追求一次性全局最优。
- 并行资源、多资源占用、学习型比较器都不属于当前实现范围。

## 7. 相关 runbook

- iOS 启动与真机安装见 [../runbooks/ios.md](../runbooks/ios.md)
- 客户端同步配置见 [../runbooks/client-sync.md](../runbooks/client-sync.md)
- 服务端部署见 [../runbooks/server-deploy.md](../runbooks/server-deploy.md)
- 恢复流程见 [../runbooks/recovery.md](../runbooks/recovery.md)
