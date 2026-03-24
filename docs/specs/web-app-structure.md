# Web App 结构与交互对齐

最后更新：2026-03-25

相关文档：

- [architecture.md](architecture.md)
- [product-model.md](product-model.md)
- [norn-mobile-structure.md](norn-mobile-structure.md)

## 1. 文档目的

本文档记录 `apps/web` 当前对齐 `apps/mobile/ios_ng/Norn/Norn` 之后的 Web 端信息架构、交互主路径和目录边界，避免后续又把 Web 退回旧式 dashboard。

本文档重点回答四件事：

- Web 端当前有哪些顶层入口
- 各入口承载什么交互语义
- `src/app` 与各 feature 目录如何分工
- Web 与 iOS 当前已经对齐、以及仍保留的边界有哪些

## 2. 当前信息架构

Web 端当前与 iOS 一样，收敛到三个顶层入口：

- `Sequence`：当前聚焦、主序列、接下来，以及只在该页出现的 Quick Add dock
- `Schedule`：时间模板编辑与按观察窗口滚动重算的时间视图
- `Task Pool`：任务搜索、列表维护、详情查看、编辑、导入导出和同步刷新

这意味着 Web 不再以单页 dashboard 作为主壳，而是使用与移动端一致的 `Sequence / Schedule / Task Pool` 主路径。

## 3. 交互对齐点

### 3.1 Sequence

- 顶部显示当前 `doing` 任务作为“当前聚焦”。
- 主序列显示 `doing` 任务和近 horizon 的 `todo` 任务。
- 主序列支持拖拽重排，并把顺序写回 `Task.extJson.norn.sequenceRank`。
- “接下来”区域承载不急于进入主序列的 `todo` 任务。
- Quick Add dock 只在 Sequence 页底部出现，并提供：
  - 直接提交 quick add
  - 把当前 quick input 提升成详细新建表单

### 3.2 Task Detail / Editor

- 点击 Sequence 卡片或 Task Pool 项，先进入任务详情，不再直接跳到编辑器。
- 详情面板提供这些快捷动作：
  - 切到进行中
  - 追加串行步骤
  - 推进当前步骤
  - 标记完成 / 恢复待办
  - 归档
- 编辑器仍由 `TaskEditModal` 承担，但它现在是详情流的二级入口，而不是默认入口。

### 3.3 Task Pool

- 保留移动端同构的 `列表 / 四象限 / 聚类` 视图模式。
- 当前只有 `列表` 接通真实任务数据；`四象限` 和 `聚类` 继续显式占位，不伪造规则。
- 任务池页承载搜索、同步刷新、Markdown 导入导出。

### 3.4 Schedule

- Web 继续保留比当前 iOS 更完整的时间视图：
  - 时间模板编辑
  - horizon 切换
  - 时间块、任务序列和 warning 展示
- 这不是与 iOS 冲突，而是当前 Web 保留的成熟能力；但外层壳、标题层级和视觉语言已与 Norn 主壳对齐。

## 4. 目录边界

当前 Web 目录边界如下：

- `src/app/App.tsx`
  - 只负责组装主壳、三 tab 切换、detail/editor modal 挂载点
- `src/app/useWebAppController.ts`
  - 当前唯一应用状态入口
  - 承担 quick add、详情、编辑、步骤推进、序列重排、同步与模板存取编排
- `src/features/sequence`
  - Sequence 页 UI、主序列拖拽、Quick Add dock
- `src/features/task-detail`
  - 任务详情 modal 与快捷动作面板
- `src/features/task-pool`
  - 任务列表、搜索、编辑器、占位视图模式
- `src/features/schedule`
  - 时间视图和排程结果渲染
- `src/features/time-template`
  - 时间模板编辑器
- `src/features/sync`
  - 远端同步访问与 LWW 合并

## 5. 当前对齐边界

当前已经对齐的部分：

- 三个顶层 tab 的信息架构
- Sequence 的聚焦卡、主序列、接下来和底部 Quick Add dock
- 任务详情先行、编辑次级进入的主路径
- 串行步骤追加、推进、完成/归档和主序列排序语义
- Task Pool 的占位视图模式结构

当前仍保留的 Web 特有边界：

- Schedule 仍然渲染完整的时间块与 horizon 视图，不降级成移动端当前占位页
- 同步配置仍以环境变量为主，Web 暂未提供 iOS 那种运行时凭据设置 sheet

## 6. 维护约束

- 再改 `Sequence / Schedule / Task Pool` 信息架构时，必须同步检查 iOS `ContentView.swift`、`SequenceTab.swift`、`TaskPoolTab.swift`、`ScheduleTab.swift`。
- 再改任务详情或编辑流程时，必须同步检查 Web `TaskDetailModal` / `TaskEditModal` 和 iOS `TaskDetailSheet` / `TaskEditorSheet`。
- 再改步骤推进、主序列顺序或 quick add 语义时，必须同步检查 `packages/core/src/norn/*` 与 iOS 对应 use case。
