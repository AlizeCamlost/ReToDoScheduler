# Web App 结构与交互对齐

最后更新：2026-04-04

相关文档：

- [architecture.md](architecture.md)
- [product-model.md](product-model.md)
- [norn-mobile-structure.md](norn-mobile-structure.md)

## 1. 文档目的

本文档记录 `apps/web` 当前对齐 `apps/mobile/ios_ng/Norn/Norn` 之后的 Web 端信息架构、交互主路径和目录边界，避免后续又把 Web 退回旧式 dashboard。

当前产品判断也一并固定在这里：手机端更适合即时查看和快速补录，系统化编辑与整理仍以桌面端为主。因此在独立桌面壳出现之前，`apps/web` 继续承担桌面工作流；后续如做 macOS / Windows 包装，也应优先复用这套 Web 壳，而不是重新发明一套桌面信息架构。

本文档重点回答四件事：

- Web 端当前有哪些顶层入口
- 各入口承载什么交互语义
- `src/app` 与各 feature 目录如何分工
- Web 与 iOS 当前已经对齐、以及仍保留的边界有哪些

## 2. 当前信息架构

Web 端当前与 iOS 一样，收敛到三个顶层入口，并保持与 iOS 一致的顺序：

- `Sequence`：当前聚焦、主序列、接下来，以及只在该页出现的 Quick Add dock
- `Task Pool`：目录浏览、脑图浏览、详情查看、导入导出，以及只在该页收口的同步刷新和运行时设置
- `Schedule`：时间模板编辑与按观察窗口滚动重算的时间视图

这意味着 Web 不再以单页 dashboard 作为主壳，而是使用与移动端一致的 `Sequence / Task Pool / Schedule` 主路径。
同时，壳顶部现在只保留全局可见的标题和设置入口；外观三态切换、同步状态与设备会话管理都收回设置面板。顶层导航不再只是本地状态切场景，而是改成真实 path 路由：`/` 对应 `Sequence`，`/task-pool` 对应 `Task Pool`，`/schedule` 对应 `Schedule`。因此刷新页面后仍会停留在当前页，浏览器前进 / 后退也会回到正确的主视图。
主标题和三枚页签也不再跟着各页内容一起参与整页滚动，而是由共享 `ShellChrome` 固定在视口壳层；只有下面的 route viewport 会按当前页内容滚动。这样切回 `Sequence` 时不会再因为 dock、内容高度或滚动条状态不同，把顶层 chrome 的位置和宽度一起带偏。顶部 segmented nav 的衬底也只包裹实际按钮组，不再伪装成整行宽条，从而保持更稳定、更干练的桌面端壳层节奏。
视觉语言上，Web 仍沿用与 iOS 对齐的语义层级，但不再硬模仿 SwiftUI 的材质和拟物光效：背景继续使用 `canvasTop -> canvasBottom` 的纵向渐变，卡片统一落在 `cardSurface / cardSurfaceMuted` 语义层，分段导航与次级按钮则维持更扁平的 pill surface。与此同时，桌面端 spacing 已收敛到更紧凑的节奏，默认只保留必要的呼吸空间，避免把主壳、卡片和 modal 做成松散的 dashboard。也就是说，Web 对齐的是信息架构和层级语义，不是把 SwiftUI 的立体感直接照搬进 CSS。

## 3. 交互对齐点

### 3.1 Sequence

- 顶部显示当前 `doing` 任务作为“当前聚焦”。
- 主序列仍以 `doing` + 近 horizon `todo` 组成，但当前序列默认只保留最优先的 7 项。
- Web 不再在浏览态直接挂拖拽；当前序列改成显式“编辑”入口，进入后才允许拖拽重排，并把顺序写回 `Task.extJson.norn.sequenceRank`。
- 编辑态直接在卡片内承载完成、编辑、归档、删除动作，而不是在浏览态混入拖拽或列表动作；拖拽提交顺序后仍保持编辑态，直到显式点“完成编辑”或真正离开该页。
- “接下来”区域改成摘要卡，承载超出前 7 项的近 horizon 任务，以及更后面的 `todo` 任务。
- Quick Add dock 只在 Sequence 页底部出现，并提供：
  - 直接提交 quick add
  - 把当前 quick input 提升成详细新建表单
  - 把当前 quick input 提升成任务序列批量录入表单
- Web 的 Quick Add 次级动作必须在输入框仍保有交互上下文时触发，不能因 blur 先把 `详情 / 序列` 按钮收掉导致点击失效。
- 批量录入后的任务会共享 `task bundle` 元数据，但当前仍按单卡展示，不折叠成组卡。

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

- Web 的 Task Pool 不再保留旧的 `列表 / 四象限 / 聚类` 信息架构，而是与 iOS 一样收敛为 `目录 / 脑图` 双模式。
- 目录模式使用上半屏导航树、下半屏当前目录目的地的垂直语义；两段都可独立折叠，并显式支持 `..` 返回上级目录。
- 目录模式承载目录 CRUD、目录移动、任务移动和“归位待整理”入口；任务详情仍通过点击任务卡片进入。
- 脑图模式使用共享的 `taskPoolOrganization.canvasNodes` 持久化目录与任务节点的位置、折叠状态，并提供拖拽、缩放和重置布局。
- 任务池页头现在只保留刷新、设置、Markdown 导入导出的显式控制入口；同步结果提示统一收进设置面板，避免在壳顶部和页内重复出现。
- “隐藏已完成任务”与外观模式仍写入浏览器本地存储，但由设置页统一控制，并同时作用于目录和脑图。
- Web 登录也统一从设置页管理同步状态与设备会话；用户可查看当前设备和其它已登录设备，并主动让其它设备退出。

### 3.4 Schedule

- Web 继续保留比当前 iOS 更完整的时间视图：
  - 时间模板编辑
  - horizon 切换
  - 时间块、任务序列和 warning 展示
- 这不是与 iOS 冲突，而是当前 Web 作为桌面编辑面的保留能力；但外层壳、标题层级和视觉语言已与 Norn 主壳对齐。

## 4. 目录边界

当前 Web 目录边界如下：

- `src/app/App.tsx`
  - 只负责组装稳定主壳、顶层 path 路由状态和 detail/editor modal 挂载点
- `src/app/ShellChrome.tsx`
  - 顶层共享壳真相源；负责渲染固定标题、主导航、设置入口和唯一的 route viewport 滚动容器
- `src/app/tabRoute.ts`
  - 顶层 path 路由真相源；负责 `pathname <-> WebAppTab` 映射和 history 写回
- `src/app/useWebAppController.ts`
  - 当前唯一应用状态入口
  - 承担 quick add、详情、编辑、步骤推进、序列重排、任务池目录/脑图组织、同步与模板存取编排
- `src/features/sequence`
  - Sequence 页 UI、主序列拖拽、Quick Add dock
- `src/features/task-detail`
  - 任务详情 modal 与快捷动作面板
- `src/features/task-pool`
  - 目录浏览器、脑图浏览器、任务编辑器，以及任务池页头工具栏
- `src/features/settings`
  - Web 外观偏好、显示配置和设备会话管理
- `src/features/schedule`
  - 时间视图和排程结果渲染
- `src/features/time-template`
  - 时间模板编辑器
- `src/features/sync`
  - 远端同步访问与 LWW 合并
- `src/features/auth`
  - Web owner 登录、会话查询、设备退出
- 本地开发时，Web 优先通过同源 `/v1/*` 与 `/health` 路径访问 API，由 Vite dev server 代理到 `127.0.0.1:8787`；这样浏览器 session cookie 不会被 `localhost` / `127.0.0.1` 混用打断

## 5. 当前对齐边界

当前已经对齐的部分：

- 三个顶层 tab 的信息架构
- Sequence 的聚焦卡、主序列、接下来和底部 Quick Add dock
- 任务详情先行、编辑次级进入的主路径
- 串行步骤追加、推进、完成/归档和主序列排序语义
- Task Pool 的 `目录 / 脑图` 双模式、目录 CRUD / 任务归位与脑图节点持久化

当前仍保留的 Web 特有边界：

- Schedule 仍然渲染完整的时间块与 horizon 视图，不降级成移动端当前占位页
- Web 继续承担桌面优先的整理与编辑工作流；手机端不需要承担全部系统化编辑密度
- Web owner 登录通过服务端会话 cookie 维持；主题模式与“隐藏已完成任务”写入浏览器本地存储；`.env` 只作为首次默认值
- 虽然 Web 不能直接复用 SwiftUI `Material`，但当前背景、card surface、dock 和 segmented nav 已按同一套语义化层级收口；后续再调样式时应继续维持扁平化 Web 表达，而不是把 SwiftUI 的拟物高光、厚阴影和材质感强行翻译成 CSS
- 顶层 chrome 的尺寸和定位必须由视口壳决定，而不是由某一页的内容高度、dock 或滚动状态反推；后续再改 `Sequence` 或 dock 编排时，也不能把标题区重新拖回内容流里

## 6. 维护约束

- 再改 `Sequence / Task Pool / Schedule` 信息架构时，必须同步检查 iOS `ContentView.swift`、`SequenceTab.swift`、`TaskPoolTab.swift`、`ScheduleTab.swift`。
- 再改任务详情或编辑流程时，必须同步检查 Web `TaskDetailModal` / `TaskEditModal` 和 iOS `TaskDetailSheet` / `TaskEditorSheet`。
- 再改步骤推进、主序列顺序或 quick add 语义时，必须同步检查 `packages/core/src/norn/*` 与 iOS 对应 use case。
