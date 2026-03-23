# 实施教训

最后更新：2026-03-24

本文件记录用户纠错后沉淀下来的具体教训。`AGENTS.md` 只负责规定“何时读取、何时复检、何时回写教训”的机制；这里负责承载教训内容本身。

## 使用方式

1. 在最终确定 roadmap 或原子任务方案前，先扫描与当前改动区域相关的教训条目。
2. 生成方案时，把这些教训当成约束，而不是实现后再补救。
3. 正式改代码前，做一次 lesson review：逐条检查方案是否触犯这些教训；若触犯，先重做方案。
4. 实现完成后、提交前，再做一次 lesson review，检查旧问题是否被重新引入。
5. 当用户指出新的、可复用的教训时，在同一轮把它补到这里，并同步更新 `docs/README.md`。

## 教训条目

### L001 声明式优先，排除 GeometryReader 式补丁

- 适用范围：SwiftUI 容器、安全区、裁剪壳、dock 编排、滚动延伸。
- 反面模式：引入 `GeometryReader`、手算 reserve / inset、普通 `padding` / `offset` 去模仿本该由声明式容器关系表达的行为。
- 正向约束：优先使用 `safeAreaInset`、`safeAreaPadding`、`overlay`、`background`、容器职责拆分和原生状态驱动。

### L002 不要删除 safeAreaInset 语义，也不要用 padding 模仿安全区延伸

- 反面模式：删除承担真实语义的 `safeAreaInset`，或用普通 `padding` 去伪造安全区避让、dock 编排或沉浸式延伸。
- 正向约束：如果问题本质上是 safe-area 语义问题，就继续用 safe-area 语义修，而不是改成命令式布局补丁。

### L003 滚动裁剪范围必须保持沉浸式 edge-to-edge 延伸

- 反面模式：修一个容器问题时，把滚动裁剪范围的 top / bottom / horizontal edge-to-edge 延伸弄丢。
- 正向约束：凡是改 page shell、safe area 或 dock 结构，都要把滚动裁剪范围延伸作为显式检查项。

### L004 Sequence 输入框在 tab 右滑时必须能自然下沉

- 反面模式：sequence 到其他 tab 的切换过程中，输入框不再下沉，或者下沉语义和 tab/page 编排脱节。
- 正向约束：涉及 root shell、tab 切换、dock 承载方式的改动时，必须显式复检输入框下沉行为。

### L005 输入框下沉不能引起滚动偏移跳变

- 反面模式：dock 的出现、消失或下沉导致 sequence 滚动位置发生肉眼可见的跳变。
- 正向约束：一切 dock 编排调整都必须把“滚动偏移稳定性”作为单独检查项。
