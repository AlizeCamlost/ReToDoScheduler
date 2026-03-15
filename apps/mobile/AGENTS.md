# Mobile Agent Notes

## Source Of Truth

- 先看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/dual-client-alignment.md`
- 再看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/product-model.md`
- 调度规则看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/scheduling-model.md`

## Current Structure

- `ios/ReToDoScheduler/App`: 根入口和应用控制器。
- `ios/ReToDoScheduler/Features/TaskPool`: 快速录入、任务列表、任务详细编辑。
- `ios/ReToDoScheduler/Features/Schedule`: 调度展示。
- `ios/ReToDoScheduler/Features/Settings`: 同步设置容器。
- `ios/ReToDoScheduler/Features/TimeTemplate`: 时间模板编辑。
- `ios/ReToDoScheduler/Shared/Domain`: 本地任务与调度类型。
- `ios/ReToDoScheduler/Shared/Services`: 仓储与同步服务。
- `ios/ReToDoScheduler/Shared/Scheduling`: 调度器。
- `ios/ReToDoScheduler/Shared/Support`: 编辑草稿与格式化工具。

## Parity Rules

- 任何涉及任务字段、时间模板、同步协议、调度展示语义的改动，都要同步核对 `apps/web`。
- `AppView.swift` 只做装配，状态和流程优先留在 `AppViewModel.swift` 或 feature/support/service 层。
- 不要重新引入 Expo、React Native、Pods 或其他已废弃的移动端残留。
