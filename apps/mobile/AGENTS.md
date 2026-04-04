# Mobile Agent Notes

## Source Of Truth

- 先看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/specs/architecture.md`
- 再看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/specs/product-model.md`
- 移动端结构看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/specs/norn-mobile-structure.md`
- 启动、签名和日常运行看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/runbooks/ios.md`
- 调度规则看 `/Users/camlostshi/Documents/ReToDoScheduler/docs/specs/scheduling-model.md`

## Current Entrypoint

- 当前维护中的 iPhone 客户端是 `apps/mobile/ios_ng/Norn/Norn`。
- 面向人的主入口是直接手动打开 `apps/mobile/ios_ng/Norn/Norn.xcodeproj`，在 Xcode GUI 里运行。
- 如果必须保留一个命令行 helper，只保留根命令 `npm run ios:open`；不要再并列 `ios:prepare`、`ios:dev`、`dev:mobile` 之类别名。
- `apps/mobile/package.json` 里的 `build`、`lint`、`xcode:build` 必须和这个工程保持一致，不要再写回旧的 `ios/ReToDoScheduler`，也不要再额外创造新的“打开工程”别名。

## Current Structure

- `ios_ng/Norn/Norn/App`: `NornApp` 入口和应用装配。
- `ios_ng/Norn/Norn/Application`: app state 和 use case 编排。
- `ios_ng/Norn/Norn/Domain`: 稳定领域模型、sync 设置和任务池组织语义。
- `ios_ng/Norn/Norn/Infrastructure`: 本地持久化、DTO 映射和 HTTP sync client。
- `ios_ng/Norn/Norn/UI`: `ContentView`、`Sequence`、`Schedule`、`Task Pool`、设置和共享组件。
- `ios_ng/Norn/Norn/Utilities`: codec、formatter 等通用支持代码。
- `ios_ng/Norn/NornTests` / `ios_ng/Norn/NornUITests`: 当前测试 target。

## Parity Rules

- 任何涉及任务字段、时间模板、同步协议、调度展示语义的改动，都要同步核对 `apps/web`。
- 涉及启动入口、工程路径或运行命令的改动时，要一起检查 `scripts/ios-open.sh`、根 `package.json`、`apps/mobile/package.json`、根 `README.md` 和 `docs/runbooks/ios.md`。
- 不要重新引入 Expo、React Native、Pods 或其他已废弃的移动端残留。
