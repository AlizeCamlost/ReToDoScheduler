# 任务池与动态调度模型

相关文档：

- [architecture.md](architecture.md)
- [product-model.md](product-model.md)

## 1. 目标

本文档定义当前任务池与动态调度实现的真相来源：

- 任务如何表达
- 调度问题如何形式化
- 首轮实现做什么，不做什么
- 调度器如何滚动重算

它是实现层规范，不承担完整产品叙事。

## 2. 问题定义

系统长期维护一个持续变化的任务池。调度器不是对一份静态输入做一次性全局求解，而是在给定观察窗口内滚动派生调度视图。

形式化表达：

> 在给定观察窗口内，将一组带有依赖、DDL、耗时和粒度约束的任务步骤装入一组时间槽中，使硬约束满足，并使总价值最大化。

调度结果包括：

- 时间块安排
- 任务序列
- 未排入步骤
- 风险与容量预警

## 3. 数据结构

### 3.1 Task

`Task` 是任务池主实体，承载：

- 标题、状态、描述
- 总耗时 `estimatedMinutes`
- 最小粒度 `minChunkMinutes`
- DDL `dueAt`
- 价值参数 `scheduleValue`
- 任务级依赖 `dependsOnTaskIds`
- 子步骤 `steps`
- 扩展字段 `extJson`

### 3.2 TaskStep

调度器真正处理的是 `TaskStep`：

- 没有子步骤的任务会展开成一个 `TaskStep`
- 有子步骤的任务会展开成多个 `TaskStep`

### 3.3 TaskGraph

`TaskGraph = TaskStep + TaskLink`

同一张图统一表达：

- 任务之间的依赖
- 任务内部子步骤序列

当前依赖语义只实现：

- `finish-to-start`

### 3.4 TimeTemplate / TimeSlot

时间模板是背景容量输入，不直接参与任务价值判断。

- `TimeTemplate`: 周期性可用时间模板
- `TimeSlot`: 由模板在观察窗口内展开出的具体时间槽

当前默认模板是工作日三段：

- `09:00-12:00`
- `14:00-18:00`
- `19:00-20:30`

### 3.5 ScheduleView

调度器对外产出：

- `blocks`
- `orderedSteps`
- `unscheduledSteps`
- `warnings`

调度视图是派生数据，不是主表。

### 3.6 首轮核心实体摘要

首轮仍保留以下核心实体关系：

- `Task`: 主任务
- `TaskStep`: 调度步骤
- `TimeTemplate`: 周期性时间模板
- `TimeSlot`: 具体时间槽
- `ScheduleBlock`: 时间块分配
- `TaskGraph`: 步骤图

## 4. 首轮实现范围

### 4.1 已纳入的能力

- 动态任务池
- 可配置观察窗口 `horizon`
- 时间模板展开
- 任务级依赖
- 任务内部子步骤
- 动态滚动重算
- 任务序列视图
- 时间块视图
- 预警输出

### 4.2 暂不做实的能力

- 并行调度
- 多资源重叠
- 学习型比较器
- 精力曲线建模
- 复杂逾期后收益函数

这些能力只保留接口和演进空间，不进入首轮求解器。

## 5. 硬约束

### 5.1 DDL

如果步骤有 `dueAt`，则完成时间不能晚于 DDL。

在首轮中：

- DDL 参与可行性过滤
- 无法在窗口内于 DDL 前完成的步骤进入未排入列表和风险预警

### 5.2 duration

同一个步骤可以拆成多个时间块，但所有块的时长和必须等于该步骤总耗时。

### 5.3 granularity

任一时间块时长必须不小于 `minChunkMinutes`。

这保证“大块任务不会被碎片空档假装完成”。

### 5.4 dependency

若存在 `A -> B`：

- `B` 不能先于 `A` 开始
- 首轮按 `finish-to-start` 处理

### 5.5 concurrency

首轮默认全部任务：

- `concurrencyMode = serial`

即同一时间只能执行一个步骤。

## 6. 价值模型

### 6.1 首轮价值结构

每个任务都带：

- `rewardOnTime`
- `penaltyMissed`

其中“错过 DDL 的损失”被视为现实输入，而不是纯主观偏好。

### 6.2 总目标

首轮目标是优先保护：

- 错过损失高的任务
- DDL 更近的任务
- 需要大块连续时间的任务

“大块任务优先”是装箱启发式，不是价值本体。

### 6.3 后续扩展空间

未来可扩展：

- 错过 DDL 后仍能止损
- 损伤随拖延膨胀
- 越早做收益越大
- 复利任务与时限任务在统一框架下比较

## 7. 比较器与调度流程

### 7.1 比较器接口

调度器依赖可插拔比较器，而不是写死排序公式。

比较器负责：

- 在多个 ready steps 中决定先看谁
- 在某个步骤的多个候选时间槽中决定放哪一个

### 7.2 动态重算触发

重算发生在：

- 任务创建
- 任务编辑
- 任务状态变化
- 任务依赖变化
- 时间模板变化
- 用户查看任务序列或调度视图

### 7.3 流程概览

```text
taskPool
  -> buildTaskSteps
  -> buildTaskGraph
  -> buildTimeSlots
  -> filter ready steps
  -> comparator selects next step/slot
  -> place step chunks
  -> build schedule view
```

## 8. 伪代码

```ts
function refreshSchedule(taskPool, timeTemplate, now, horizon, comparator) {
  const steps = buildTaskSteps(taskPool);
  const graph = buildTaskGraph(taskPool, steps);
  const slots = buildTimeSlots(timeTemplate, horizon);

  const state = {
    steps,
    graph,
    slots,
    remainingMinutesByStepId: indexRemainingMinutes(steps),
    blocks: [],
    warnings: []
  };

  while (hasUnfinishedSteps(state)) {
    const readySteps = findReadySteps(state, comparator);
    const nextPlacement = pickNextPlacement(readySteps, state, comparator);
    if (!nextPlacement) break;
    placeStepChunk(nextPlacement, state);
  }

  return buildScheduleView(state);
}
```

关键点：

- 同一 `TaskStep` 可以被拆成多个 `ScheduleBlock`
- 每个块必须满足最小粒度
- 若存在循环依赖，应直接返回 dependency warning

## 9. 与当前代码的映射

当前代码中的稳定映射包括：

- `Task`
- `TaskStep`
- `TaskGraph`
- `TimeTemplate`
- `ScheduleBlock`
- `ScheduleView`

首轮工程实现采用渐进落地方式：

- 调度字段可以先通过 `extJson.taskModel` 携带
- 再逐步提升为正式 schema / API / UI 字段

## 10. 结论

当前调度模型的核心判断是：

- 系统长期维护的是任务池，不是静态日程表
- 调度本质上是“硬约束 + 价值最大化”的滚动装箱问题
- 任务依赖与子步骤依赖应统一进同一张图
- 首轮实现先做必要复杂度，为后续并行、资源和学习能力预留骨架
