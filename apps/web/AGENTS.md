# Web Agent Notes

## Source Of Truth

- 先看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/dual-client-alignment.md`
- 再看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/product-model.md`
- 调度规则看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/scheduling-model.md`

## Current Structure

- `src/app`: 入口和应用控制器，不放具体 feature 业务组件。
- `src/features/task-pool`: 任务池与任务编辑。
- `src/features/schedule`: 调度视图。
- `src/features/time-template`: 时间模板编辑。
- `src/features/sync`: 远端同步访问。
- `src/shared`: 配置、浏览器存储、导入导出、通用工具。

## Parity Rules

- 改字段、流程、信息架构时，必须同步检查 `apps/mobile` 的对应 feature。
- 不要把时间模板、任务导入导出、device id、env 配置重新塞回 `App.tsx`。
- `App.tsx` 只负责装配；状态和副作用优先放到 `src/app/useWebAppController.ts` 或 feature/data 层。
