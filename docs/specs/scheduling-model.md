# 调度模型

相关文档：

- [architecture.md](architecture.md)
- [product-model.md](product-model.md)

## 1. 问题定义

调度器面对的核心因素只有两类：

- 硬约束
- 价值最大化

形式化表达：

> 在给定观察窗口内，将一组带有硬约束的任务步骤装入一组时间槽中，使硬约束满足，并使总价值最大化。

在这个框架下：

- 新的现实限制进入硬约束
- 新的取舍理念进入价值评估或比较器
- 不再平行发明第三类调度本体

调度结果包括：

- 时间块安排
- 任务序列
- 未排入步骤
- 风险与容量预警

## 2. 核心实体

- `Task`: 任务池主实体，承载标题、状态、估时、最小块、DDL、价值、依赖和子步骤
- `TaskStep`: 调度器真正处理的步骤单元；一个任务可展开为一个或多个步骤
- `TaskGraph`: 由步骤和依赖边构成的统一图，同时表达任务间依赖和任务内子步骤序列
- `TimeTemplate` / `TimeSlot`: 背景容量输入，不直接定义价值
- `ScheduleView`: 对外输出的派生视图

## 3. 硬约束

### 3.1 deadline

- 若步骤有 `dueAt`，则完成时间不能晚于 DDL
- 无法在窗口内于 DDL 前完成的步骤进入未排入列表和风险预警

### 3.2 timecost

- `estimatedMinutes` 表示总耗时
- 同一 `TaskStep` 可以拆成多个时间块
- 所有时间块之和必须等于该步骤总耗时

### 3.3 granularity

- 任一时间块时长必须不小于 `minChunkMinutes`
- 这保证大块任务不会被碎片空档假装完成

### 3.4 dependency

- 若存在 `A -> B`，则 `B` 不能先于 `A` 开始
- 当前只实现 `finish-to-start`
- “一串子任务”只是 dependency 的特殊形态，应与任务间依赖统一进同一张图

### 3.5 concurrency

- 当前默认 `concurrencyMode = serial`
- 即同一时间只安排一个步骤
- 未来如扩展并行，也仍属于硬约束层，不改变整体问题定义

## 4. 价值目标

当前系统把每个任务的基础价值写成一个二元组：

- `rewardOnTime`
- `penaltyMissed`

这表示：

- DDL 前完成带来的收益
- 错过 DDL 带来的损失

现实中的价值判断来源可以继续扩展，例如：

- 生死轴，即“争得 ↔ 避祸”
- 复利收益，如技能、资历、人际关系、声誉、影响力
- 现实损失，如违约、阻塞、事故、窗口关闭

但这些扩展最终都必须回到可比较的价值输入，而不是绕开调度模型另起炉灶。

## 5. 比较器

调度器依赖可插拔比较器，而不是写死一个永恒排序公式。

比较器负责两件事：

- 在多个 ready steps 中决定先处理谁
- 在某个步骤的多个候选时间槽中决定放哪一个

这意味着以下策略都只是插件化启发式，而不是问题本体：

- 大块任务优先
- 高损失任务优先
- 更近 DDL 优先
- 对复利任务给额外偏置
- 对特定干系人任务给额外偏置

## 6. 滚动求解流程

```text
taskPool
  -> buildTaskSteps
  -> buildTaskGraph
  -> buildTimeSlots
  -> findReadySteps
  -> comparator selects next step / slot
  -> place step chunks
  -> build schedule view
```

重算触发包括：

- 任务创建或编辑
- 任务状态变化
- 任务依赖变化
- 时间模板变化
- 用户查看任务序列或调度视图

## 7. 当前实现边界

- 当前是滚动启发式求解，不是一次性全局最优求解器
- 当前仍是单资源、串行执行
- 当前不做多资源重叠和复杂并行调度
- 当前不做学习型比较器和复杂逾期价值函数
- 这些都是后续增强项，但仍应纳入“硬约束 + 价值最大化”框架

## 8. 与代码的稳定映射

- `Task.scheduleValue` 对应当前价值二元组
- `Task.dependsOnTaskIds` 和 `Task.steps[].dependsOnStepIds` 共同构成依赖图
- `Task.minChunkMinutes` 对应最小粒度约束
- `Task.concurrencyMode` 对应并行约束
- `ScheduleView` 输出 `blocks`、`orderedSteps`、`unscheduledSteps`、`warnings`
