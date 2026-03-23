# Project Memory

## Docs Policy

- `docs/` 根目录只保留索引文件 `docs/README.md`，不再放活动文档。
- 活动文档只能进入 `docs/specs/`、`docs/runbooks/`、`docs/guides/`、`docs/adr/`。
- 历史材料只能进入 `docs/archive/`。
- 一个主题只保留一个活动真相源；被新文档吸收的旧文档应删除，只有确有追溯价值时才归档。

## Docs Index Policy

- `docs/README.md` 是文档总索引，必须列出当前收录的文档及其作用。
- `docs/README.md` 中每个条目都必须带 `最后更新：YYYY-MM-DD`。
- 以后每次修改已收录文档，都必须同步更新 `docs/README.md` 对应条目的日期。
- 如果新增、移动、删除文档，必须同时更新 `docs/README.md` 的目录结构和条目说明。

## Spec Sync Policy

- 任何规格设计、实现行为、交互语义、目录结构的变更，都必须同步更新到 `docs/` 下对应的活动文档。
- 如果当前变更影响现有文档的描述、示意、实施状态或目录索引，必须在同一轮修改中一并更新，不能只改代码不改文档。
- 如果找不到合适的现有文档承接变更，先补充到最相关的活动文档，再按 `Docs Policy` 决定是否需要新增文档。

## Feature Delivery Policy

- 对多文件、跨层级、超过单点修补的 feature 变更，默认先输出 feature 拓扑 roadmap，再开始实现。
- roadmap 的首要目标是把需求切成易检视、易验证、边界清晰的小任务，而不是先写实现细节。
- 如果识别到任务高度集中、内聚且继续拆分不会提升 review 或验证价值，可以把它视为 roadmap / 拓扑中的原子任务；允许 roadmap 只有一个节点，并只对应一个 commit。
- 即使是原子任务，也仍需在 roadmap 中明确它的目标、边界、验证方式和对应 commit message，而不是跳过 roadmap discipline。
- roadmap 必须识别这些小任务之间的拓扑依赖，明确哪些任务阻塞后续任务、哪些任务可以独立推进。
- roadmap 必须明确说明改动目标、涉及目录/文件边界、依赖关系、验证方式，以及建议的分步提交顺序。
- 小步提交计划应当从 roadmap 的任务切分和拓扑依赖自然导出；每个 commit 都应尽量对应一个独立、可 review、可验证的小任务。
- 提交计划必须拆成小步、可 review 的 commit，并提前给出每一步对应的 commit message。
- roadmap 一旦获用户确认，后续实现必须严格按该提交计划小步推进；完成一个独立任务后应立即提交，再进入下一个任务，不能把多个 roadmap 节点批量实现后再一起处理。
- 如果本轮实现偏离了既定 commit 拆分，必须先停下说明偏离原因并重新取得用户确认；不能跳过小步提交纪律继续堆积未提交改动。
- roadmap 还应显式识别并行开发的可能性；对写入边界清晰、依赖解耦的小任务，可以并行推进。
- 如果 roadmap 识别出可并行切分，允许检出新的子分支或新 worktree，并通过 subagent / agent team 的形式并行工作。
- 并行开发的最终要求是把这些分支上的成果合回当前工作的 feature branch，并在 merge 前重新确认依赖关系、冲突面和验证结果。
- 如果用户本轮明确要求“先看计划 / roadmap / commit 拆分”，在用户确认前不要直接开始代码实现。

## Declarative UI Policy

- 在任何可行情况下，优先使用声明式 SwiftUI 容器关系和修饰符实现布局、裁剪、安全区和动效；默认排除命令式或亲命令式写法。
- 默认不要引入 `GeometryReader`、手算 reserve / inset、普通 `padding` 或 `offset` 去模拟安全区避让、滚动裁剪范围、dock 编排或页面壳行为。
- 对这类问题，优先使用 `safeAreaInset`、`safeAreaPadding`、`overlay`、`background`、容器层级拆分和原生状态驱动。
- 若确实不存在可行的声明式方案，使用 `GeometryReader` 或其他命令式补丁前，必须先停下说明 declarative 方案为何不成立，再取得确认。
- 对当前 iOS 容器壳，优先检查并维持这三个声明式职责层：
- root `safeAreaInset` 负责 Sequence 输入 dock 的下沉/出现编排，以及避免横向切 tab 时引入滚动偏移跳变。
- root page shell 的 `ignoresSafeArea` 负责滚动裁剪范围的 edge-to-edge 延伸。
- 各 tab wrapper 的 `safeAreaPadding` 负责内容本身对圆角、灵动岛、触控条的避让。
- 不要把这三层职责重新揉在一起，也不要把其中一层改写成命令式补丁。

## Regression Memory Policy

- 对用户已经明确生气、反复强调、纠正过，甚至出现过“改正后又再次犯错”的问题，必须固化到项目级记忆中；后续实现前先检查一遍，不可再次引入。
- 当前已知不可再犯项：
- 不要用 `GeometryReader`、手算 reserve / inset、普通 `padding` 去替代 `safeAreaInset` / `safeAreaPadding` 的语义。
- 不要破坏 Sequence 输入 dock 的下沉编排，以及横向切 tab 时不引起滚动偏移跳变的结构。
- 不要丢失滚动裁剪范围的 top / bottom / horizontal edge-to-edge。
- 不要丢失横屏下对圆角、灵动岛、触控条的 safe-area 避让。
- 不要混淆 page shell 的裁剪职责、dock 的编排职责和内容本身的 safe-area 职责。
- 调整内容 safe-area 避让时，不要机械地四边同时加大；竖屏主避让方向是 top / bottom，横屏主避让方向是 left / right。
- 对当前 Norn 壳层，Sequence 在竖屏主要补 top safe-area，bottom 继续交给 dock reserve；横屏主要补 horizontal safe-area，避免无谓压缩宽度。

## Practical Rule

- 做任何规格或实现改动时，默认先检查受影响的活动文档和 `docs/README.md` 是否也需要同步更新。
