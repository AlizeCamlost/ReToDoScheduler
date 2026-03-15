# 双端实现对齐说明

本文档是 `apps/web` 与 `apps/mobile` 的活动对照表，供人和 agent 在后续修改时共同遵守。

## 真相来源

- 产品语义以 `docs/product-model.md` 为准。
- 调度与容量规则以 `docs/scheduling-model.md` 为准。
- 仓库分层和同步边界以 `docs/architecture.md` 为准。

## 双端共同功能边界

- `TaskPool`: 任务列表、搜索、完成/归档、任务详细编辑。
- `Schedule`: 观察窗口切换、时间块、任务序列、未排入预警。
- `TimeTemplate`: 周时间段维护，作为调度器背景容量输入。
- `Sync`: 本地优先，配置远端地址和令牌后做全量 LWW 同步。

## 目录对照

### Web

- `src/app`: 根入口和应用控制器。
- `src/features/task-pool`: 任务池 UI。
- `src/features/schedule`: 调度视图 UI。
- `src/features/time-template`: 时间模板 UI。
- `src/features/sync`: 远端同步数据访问。
- `src/shared`: 配置、存储、工具函数。

### Mobile

- `App`: 根入口和应用控制器。
- `Features/TaskPool`: 任务池 UI。
- `Features/Schedule`: 调度视图 UI。
- `Features/Settings`: 同步设置容器。
- `Features/TimeTemplate`: 时间模板 UI。
- `Shared/Domain`: 本地任务与调度类型。
- `Shared/Services`: 本地仓储与同步服务。
- `Shared/Scheduling`: 本地调度器。
- `Shared/Support`: 格式化与编辑草稿。

## 修改约束

- 如果改了任务编辑字段，要同时检查 Web `TaskEditModal` 和 iOS `TaskEditorSheet`。
- 如果改了时间模板结构，要同时检查 Web `timeTemplateStore` 和 iOS `TaskRepository` 的存取逻辑。
- 如果改了调度展示语义，要同时检查 Web `SchedulePanel` 和 iOS `ScheduleSection`。
- 如果改了同步协议，要同时检查 Web `features/sync/data/taskSync.ts` 和 iOS `Shared/Services/SyncService.swift`。
- 只做单端 UI 样式调整可以单独改；只要涉及字段、流程、信息架构，就必须同步审视另一端。
