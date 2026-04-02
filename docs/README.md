# 文档目录

最后更新：2026-04-02

`docs/` 根目录只保留这个索引。当前真相源、runbook、协作指南和历史材料全部放在子目录下。

时间标记规则：

- 本索引对每个收录文档都标记 `最后更新：YYYY-MM-DD`。
- 以后每次修改 `docs/` 下的活动文档或归档索引，都必须同步更新这里对应条目的日期。
- 新文档仍按 `specs/`、`runbooks/`、`guides/`、`adr/`、`archive/` 组织，不再把活动文档放回 `docs/` 根目录。

## specs

- [specs/architecture.md](specs/architecture.md): 当前系统架构真相源。定义运行时分层、仓库职责、数据流、最小 Task sync contract，以及并行同步 `TaskPoolOrganizationDocument` 的双端对齐约束，并补充 Web 端本地同步设置与显示配置职责。最后更新：2026-04-02
- [specs/norn-mobile-structure.md](specs/norn-mobile-structure.md): Norn iOS_ng 的当前目录快照、目标类型地图、调用关系和 feature 提交拓扑，并同步记录根容器背景、全屏 edge-to-edge 分页裁剪壳、root scoped Sequence dock safeAreaInset、固定化的 dock reserve、Quick Add 拉起任务序列编辑器的批量录入路径，以及任务 bundle 标识的单卡展示边界；当前 `Sequence` 已收敛为更紧凑的“当前聚焦 + 当前序列 + 接下来摘要”，浏览态不挂拖拽，长按进入编辑态后只让卡片接管悬停拖拽与左滑托盘动作，卡片外区域继续保留页面滚动与翻页，且当前序列默认只保留最优先的 7 项；任务池则已收敛为 `目录 / 脑图` 双模式，顶层只保留标题、刷新和设置入口，同步状态与“隐藏已完成任务”开关已收进设置页，目录视图也进一步改成带横向留白的沉浸式导航树 + 当前目录目的地，并显式支持两段独立折叠、`..` 返回上级目录和更紧凑的子目录列表。当前实施状态：F20 已完成。最后更新：2026-04-02
- [specs/product-model.md](specs/product-model.md): 当前产品语义真相源。定义 Norn / Kairos 边界、任务池核心抽象、价值语义和输入契约，并补充目录树 / 画布共用的 `TaskPoolOrganizationDocument` 语义。最后更新：2026-03-31
- [specs/scheduling-model.md](specs/scheduling-model.md): 当前调度模型真相源。把 Kairos 明确为“硬约束 + 价值最大化”的滚动装箱问题，并说明比较器接口与实现边界。最后更新：2026-03-22
- [specs/web-app-structure.md](specs/web-app-structure.md): Web 端当前对齐 Norn 移动端后的主壳、三 tab 信息架构、详情流、Sequence 交互和 feature 边界真相源，并同步记录 Web 运行时同步设置、显式进入的 Sequence 编辑态、7 项当前序列上限、Quick Add 的任务序列入口与 bundle 标识展示。最后更新：2026-04-02

## runbooks

- [runbooks/client-sync.md](runbooks/client-sync.md): Web、iPhone、API 的最小 Task 模型与 `taskPoolOrganization` 文档同步配置、联调验证和排障步骤，并补充 Web `设置` 页的运行时同步配置流程。最后更新：2026-04-02
- [runbooks/ios.md](runbooks/ios.md): iOS 原生工程打开、真机安装、日常运行和最小同步配置，并补充 `任务池` 现位于第二个顶层分页入口，默认展示 `目录` 并可切换到 `脑图`，同步状态与“隐藏已完成任务”开关统一位于设置页，目录页已收敛为带横向留白的上半屏导航树 + 下半屏当前目录目的地并支持独立折叠、`..` 返回上级目录和更紧凑的子目录列表，`Sequence` 当前序列则需长按进入编辑态后才支持卡片内悬停拖拽与左滑托盘动作。最后更新：2026-04-02
- [runbooks/server-deploy.md](runbooks/server-deploy.md): API + PostgreSQL 的首轮部署、校验、日常运维、备份和 GitHub Actions 部署说明，并记录当前生产部署绕过 `docker compose build`、改用 `DOCKER_BUILDKIT=0 docker build` 的过渡性约束，以及待业务形态稳定后再重新评估的边界。最后更新：2026-04-01
- [runbooks/recovery.md](runbooks/recovery.md): 本地和远端恢复的停写、恢复、校验、复盘流程。最后更新：2026-03-22

## guides

- [guides/implementation-lessons.md](guides/implementation-lessons.md): 项目级实施教训真相源。记录用户纠错后的具体教训，以及生成方案前后的 lesson review 工作流，并补充 `Sequence` route B 下不要再赌 `ScrollView` 行内系统 `swipeActions` 的约束。最后更新：2026-04-02
- [guides/ui-design-process.md](guides/ui-design-process.md): AI 协作做 UI 时的决策方法论，用于减少“代码先生成、决策却没发生”的问题。最后更新：2026-03-22

## adr

- [adr/0001-monorepo-and-stack.md](adr/0001-monorepo-and-stack.md): 为什么采用 monorepo 和当前技术栈。最后更新：2026-03-15
- [adr/0002-local-first-sync.md](adr/0002-local-first-sync.md): 为什么采用 local-first + LWW 同步策略。最后更新：2026-02-20

## archive

- [archive/README.md](archive/README.md): 历史材料索引和保留标准。最后更新：2026-03-22
- [archive/specs/product-spec-v1.md](archive/specs/product-spec-v1.md): 2026-03 中旬的旧版系统设计规格，保留作历史里程碑，不再作为当前真相源。最后更新：2026-03-22
- [archive/source-notes/README.md](archive/source-notes/README.md): 原始设计素材目录的索引和保留约束。最后更新：2026-03-22

## 维护规则

- 新的活动规范只能进入 `specs/`、`runbooks/`、`guides/` 或 `adr/`，不要再把活动文档放回根目录。
- 一个主题只保留一个活动真相源。被吸收的旧文档直接删除，确有追溯价值时再放入 `archive/`。
- `archive/` 只保留历史节点和原始素材，不保留重复教程、过时 runbook 或已经被新文档逐段覆盖的草稿。
- 修改任何已收录文档后，必须同步更新本索引中的“最后更新”日期。
