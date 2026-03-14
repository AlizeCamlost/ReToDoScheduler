# 任务池与动态调度设计

> 状态：草稿
> 目标：定义任务数据结构、动态调度模型、首轮实现范围与调度伪代码

## 1. 目标与边界

本文档定义一套围绕“任务池 + 动态调度”的统一模型。

- `任务池` 负责长期维护任务及其结构化信息。
- `调度器` 负责从任务池中，在给定时间尺度内，动态派生可查看的任务序列和时间块安排。
- `调度视图` 是派生结果，不是唯一真相源。

本文档只回答三个问题：

1. 任务需要什么数据结构，才能描述当前已识别的决策因素。
2. 调度问题如何形式化为“硬约束 + 价值最大化”的装箱问题。
3. 第一轮实现应做到什么，未来扩展预留在哪里。

本文档不覆盖：

- UI 布局与交互细节
- AI 解析 prompt 设计
- 数据库存储细节
- 学习型排序器的训练方法

## 2. 命名原则

在概念层面，代码目录和文档中仍可保留 `Norn` / `Kairos` 作为模块边界：

- `Norn`：任务池维护层
- `Kairos`：动态调度层

但在具体类名、函数名、变量名、产品文案中，统一使用朴素语义化命名：

- `Task`
- `TaskStep`
- `TaskLink`
- `TaskGraph`
- `TimeTemplate`
- `TimeSlot`
- `ScheduleBlock`
- `ScheduleView`
- `Scheduler`

推荐函数名：

- `refreshSchedule`
- `buildTaskSteps`
- `buildTaskGraph`
- `buildTimeSlots`
- `findCandidates`
- `pickNextStep`
- `placeStep`
- `repairSchedule`

原则是：模块名可以抽象，具体命名保持直白。

## 3. 总体模型

### 3.1 动态任务池

系统不是一次性输入、一趟求解、一次性输出。

系统长期维护一个持续变化的任务池：

- 新任务会随时加入
- 旧任务会被修改
- 任务会进入进行中、完成、归档等状态
- 任务的子步骤、依赖关系、估时、DDL、价值参数都可能变化

因此调度器不维护一份静态总计划，而是持续地从任务池派生调度结果。

### 3.2 动态调度视图

调度器的输入：

- 当前任务池
- 时间模板
- 当前时刻 `now`
- 一个可配置的观察窗口 `horizon`
- 一个可插拔的比较器 `comparator`

调度器的输出：

- 在 `horizon` 内的任务序列
- 在 `horizon` 内的时间块安排
- 未能排入的高风险任务
- 容量不足、DDL 冲突、依赖阻塞等预警

这里的 `horizon` 是泛化概念，不预设固定枚举。它可以是：

- `1 day`
- `7 days`
- `21 days`
- `6 weeks`

也可以由调用者自由指定。

### 3.3 调度刷新触发

调度应在以下事件后重新派生：

- 任务被创建
- 任务被编辑
- 任务状态改变
- 任务依赖改变
- 时间模板改变
- 任务序列被查看

最后一条等价于“每次用户查看调度时，系统都基于当前状态重新计算或增量刷新”。

## 4. 问题形式化

可以把问题表述为：

> 在给定观察窗口内，将一组有依赖关系、DDL、耗时和粒度约束的任务步骤，装入一组时间槽中，使硬约束全部满足，并使总价值最大化。

这里有两层：

- `硬约束`：决定“能不能放进去”
- `价值函数`：决定“放哪个更值”

### 4.1 硬约束

第一轮明确纳入的硬约束：

- `DDL`
- `duration`
- `granularity`
- `dependency`

保留但暂不启用复杂求解的约束：

- `concurrency`

### 4.2 目标函数

第一轮目标函数围绕“按时收益 + 逾期损失”建模：

- 任务按时完成可获得收益
- 任务错过 DDL 会产生损失

这里的“错过 DDL 的损失”不是主观偏好，而是任务的现实输入。

### 4.3 动态而非静态

这个装箱问题不是一次求全局最优后永久不变，而是一个滚动重算问题：

- 任务池会变
- 可用时间会被消耗
- 当前时刻会推进
- 观察窗口会变化

因此调度器追求的是“在当前状态下给出足够好的可执行安排”，而不是一次性离线最优解。

## 5. 核心数据结构

以下是建议的数据结构草案。语义优先，字段名可在实现时微调。

### 5.1 Task

`Task` 是任务池中的主实体，代表用户视角下的一个任务。

```ts
type TaskStatus = "todo" | "doing" | "done" | "archived";

type ConcurrencyMode = "serial";

interface TaskValue {
  rewardOnTime: number;
  penaltyMissed: number;
}

interface TaskStepTemplate {
  id: string;
  title: string;
  durationMinutes: number;
  minChunkMinutes: number;
  dependsOnStepIds: string[];
}

interface Task {
  id: string;
  title: string;
  status: TaskStatus;
  description?: string;

  dueAt?: string;
  durationMinutes: number;
  minChunkMinutes: number;

  value: TaskValue;
  concurrencyMode: ConcurrencyMode;

  dependsOnTaskIds: string[];
  steps?: TaskStepTemplate[];

  createdAt: string;
  updatedAt: string;
  ext: Record<string, unknown>;
}
```

说明：

- `durationMinutes` 是任务整体耗时
- `minChunkMinutes` 表示最小可切分粒度
- `dependsOnTaskIds` 用于任务级依赖
- `steps` 用于表达任务内部的子步骤序列或局部依赖结构
- 第一轮 `concurrencyMode` 固定为 `serial`

### 5.2 TaskStep

`TaskStep` 是调度器真正参与装箱的单位。它由任务直接展开，或由任务内子步骤展开。

```ts
interface TaskStep {
  id: string;
  taskId: string;
  title: string;

  durationMinutes: number;
  minChunkMinutes: number;
  dueAt?: string;

  value: TaskValue;
  concurrencyMode: ConcurrencyMode;

  source: "task" | "task-step";
}
```

设计原则：

- 调度器只面向 `TaskStep` 求解
- 一个没有子步骤的任务会展开成一个 `TaskStep`
- 一个带子步骤的任务会展开成多个 `TaskStep`

### 5.3 TaskLink

`TaskLink` 用于统一表达依赖边。

```ts
type TaskLinkType = "finish-to-start";

interface TaskLink {
  fromStepId: string;
  toStepId: string;
  type: TaskLinkType;
}
```

说明：

- 任务间依赖会被转换成步骤间依赖
- 任务内部子步骤序列也会被转换成步骤间依赖
- 第一轮只实现最常见的 `finish-to-start`

### 5.4 TaskGraph

`TaskGraph` 是 `TaskStep + TaskLink` 组成的 DAG。

```ts
interface TaskGraph {
  steps: TaskStep[];
  links: TaskLink[];
}
```

这样做的好处是：

- “任务之间的依赖”
- “任务内部的子步骤序列”

都进入同一张图里，调度算法只需要处理一种依赖模型。

### 5.5 TimeTemplate

`TimeTemplate` 描述周期性可用时间，不直接参与装箱，而是用于展开观察窗口内的 `TimeSlot`。

```ts
interface WeeklyTimeRange {
  weekday: 1 | 2 | 3 | 4 | 5 | 6 | 7;
  startTime: string; // HH:mm
  endTime: string;   // HH:mm
}

interface TimeTemplate {
  weeklyRanges: WeeklyTimeRange[];
  timezone: string;
}
```

当前已知的时间模板，可先按工作日固定时间段建模：

- `09:00-12:00`
- `14:00-18:00`
- `19:00-20:30`

按你当前给出的信息，第一轮可先配置为周一到周五共用这三段时间；如果后续周内差异需要显式建模，只需在 `weeklyRanges` 中继续细分。

### 5.6 TimeSlot

`TimeSlot` 是在观察窗口内由模板展开出的具体可调度时间槽。

```ts
interface TimeSlot {
  id: string;
  startAt: string;
  endAt: string;
  durationMinutes: number;
}
```

第一轮中，`TimeSlot` 只承载时间信息，不承载复杂资源维度。

### 5.7 ScheduleBlock

`ScheduleBlock` 代表一个步骤被分配到某个时间槽中的具体区间。

```ts
interface ScheduleBlock {
  stepId: string;
  taskId: string;
  slotId: string;
  startAt: string;
  endAt: string;
}
```

### 5.8 ScheduleView

`ScheduleView` 是调度器对外暴露的派生结果。

```ts
interface ScheduleView {
  horizonStart: string;
  horizonEnd: string;
  blocks: ScheduleBlock[];
  orderedSteps: TaskStep[];
  unscheduledSteps: TaskStep[];
  warnings: string[];
}
```

`orderedSteps` 用于任务序列视图，`blocks` 用于时间块视图。

## 6. 第一轮实现范围

第一轮只实现必要核心，不把扩展点过早做实。

### 6.1 纳入首轮的数据能力

- 任务池中的任务增删改查
- 任务级 DDL
- 任务总耗时
- 最小切分粒度
- 任务间依赖
- 任务内部子步骤序列
- 周期性时间模板
- 可配置观察窗口
- 调度结果的任务序列视图
- 调度结果的时间块视图

### 6.2 纳入首轮的调度规则

- 先检查硬约束，再谈价值比较
- 调度单位统一为 `TaskStep`
- 依赖统一进 `TaskGraph`
- 支持动态重算
- 支持插件化比较器
- 默认比较器采用启发式方法，不追求一次性全局最优

### 6.3 首轮明确不做实的能力

- 并行调度
- 多资源占用模型
- 精力曲线
- 学习型比较器
- 复杂逾期价值函数
- 概率型耗时推断

这些能力只保留字段和结构接口，不在第一轮求解器中引入复杂度。

## 7. 未来规划

未来扩展主要沿四条线推进。

### 7.1 并行与资源

当前所有任务默认视为不可并行。

未来可扩展：

- 与低认知负载任务并行
- 占用不同资源时可重叠
- 更丰富的资源约束和重叠规则

这会显著提高装箱复杂度，但也能提升时间利用率。

### 7.2 逾期后的止损与损伤膨胀

未来可支持更复杂的时间价值函数：

- 错过 DDL 后仍可止损
- 错过 DDL 后仍有正收益
- 延期越久，损伤越大
- 损伤与拖延时长存在映射关系

### 7.3 复利任务的提前收益

有些任务并不由硬 DDL 驱动，而是“越早做，收益越大”。

未来可支持：

- 提前完成带来的增益函数
- 复利任务与时限任务在同一价值框架下比较

### 7.4 学习型比较器

未来比较器可吸收用户历史调整：

- 用户拖拽顺序
- 手动换位
- 提前或推迟某类任务的稳定偏好

但这应建立在首轮规则足够清晰后再做。

## 8. 硬约束模型

### 8.1 DDL

如果步骤有 `dueAt`，则步骤的完成时间不能晚于该 DDL，否则视为逾期。

第一轮中：

- DDL 既参与可行性判断
- 也参与价值判断

当观察窗口内根本不可能按时完成时，系统应给出预警，而不是假装可行。第一轮中，这类步骤不应被排到 DDL 之后，而应进入未排入列表和风险提示。

### 8.2 duration

步骤必须占用足够总时长。

约束形式：

- 分配到该步骤的所有时间块时长之和
- 必须等于 `TaskStep.durationMinutes`

同一个 `TaskStep` 可以被拆成多个 `ScheduleBlock`，但必须由调度器显式分配这些块。

### 8.3 granularity

每个分配块的连续时长必须满足最小粒度约束。

约束形式：

- 任一时间块时长
- 必须大于等于 `TaskStep.minChunkMinutes`

如果一个步骤要求最小粒度为 `120` 分钟，那么多个碎片化的 `30` 分钟空档不能替代它。

### 8.4 dependency

若存在 `A -> B` 的依赖边，则：

- `B` 不能先于 `A` 开始
- 更严格地说，第一轮按 `finish-to-start` 处理：
  `B.startAt >= A.finishAt`

### 8.5 concurrency

第一轮中，所有任务默认：

- `concurrencyMode = "serial"`

等价于：

- 同一时间内，一个步骤不能与另一个步骤重叠执行

字段先保留，求解器先简化。

## 9. 价值模型

### 9.1 基本结构

第一轮采用最小可用的价值结构：

```ts
interface TaskValue {
  rewardOnTime: number;
  penaltyMissed: number;
}
```

完成时间为 `finishedAt`，DDL 为 `dueAt` 时：

- 若 `finishedAt <= dueAt`，获得 `rewardOnTime`
- 若 `finishedAt > dueAt`，承担 `penaltyMissed`

第一轮中，由于 DDL 被当作硬约束，`penaltyMissed` 主要用于：

- 估计未排入步骤的现实损失
- 比较“优先保护谁”
- 为风险提示提供定量依据

而不是鼓励系统把任务直接排到 DDL 之后。

### 9.2 总价值

调度器的目标是最大化观察窗口内的总价值：

```text
totalValue = sum(stepValue(step, finishedAt))
```

第一轮的 `stepValue` 可近似为：

```text
if no dueAt:
  rewardOnTime
else if finishedAt <= dueAt:
  rewardOnTime
else:
  -penaltyMissed
```

### 9.3 未来的时间价值函数

为了支持后续增强，可为每个任务预留更一般的时间价值函数接口：

```ts
interface TimeValueRule {
  mode: "fixed" | "time-based";
  ext?: Record<string, unknown>;
}
```

未来可表达：

- 错过 DDL 但仍有残余收益
- 越拖越亏
- 越早做越赚

第一轮不实际求解这些复杂函数，只保留扩展口。

## 10. 比较器插件接口

调度器不把排序规则写死，而是依赖比较器插件。

```ts
interface ComparatorContext {
  now: string;
  horizonStart: string;
  horizonEnd: string;
}

interface Comparator {
  compareSteps(a: TaskStep, b: TaskStep, context: ComparatorContext): number;
  scoreCandidate(step: TaskStep, slot: TimeSlot, context: ComparatorContext): number;
}
```

职责分工：

- `compareSteps`：当多个步骤都已就绪时，比较谁应更先被考虑
- `scoreCandidate`：当某个步骤有多个可选时间槽时，比较放哪一个更合适

第一轮默认比较器建议优先考虑：

- 错过 DDL 损失高的任务
- DDL 更近的任务
- 需要大块连续时间的任务
- 已经就绪且无阻塞的任务

其中“大块任务优先”是装箱启发式，不是价值本体。

## 11. 动态调度流程

### 11.1 流程概览

```text
taskPool
  -> buildTaskSteps
  -> buildTaskGraph
  -> buildTimeSlots
  -> find ready steps
  -> comparator selects next step/slot
  -> place step chunk
  -> repair schedule
  -> build schedule view
```

### 11.2 关键思想

调度流程应分成四层：

1. 展开结构
2. 过滤可行性
3. 启发式装箱
4. 局部修复

这样做的好处是：

- 硬约束清晰
- 比较器职责清晰
- 后续增强不会推翻整体结构

## 12. 伪代码

### 12.0 调度状态

```ts
interface SchedulerState {
  now: Date;
  horizon: { startAt: Date; endAt: Date };
  steps: TaskStep[];
  graph: TaskGraph;
  slots: TimeSlot[];
  remainingMinutesByStepId: Record<string, number>;
  blocks: ScheduleBlock[];
  warnings: string[];
}
```

### 12.1 刷新入口

```ts
function refreshSchedule(
  taskPool: Task[],
  timeTemplate: TimeTemplate,
  now: Date,
  horizon: { startAt: Date; endAt: Date },
  comparator: Comparator
): ScheduleView {
  const steps = buildTaskSteps(taskPool);
  const graph = buildTaskGraph(taskPool, steps);
  const slots = buildTimeSlots(timeTemplate, horizon);

  const initialState = {
    now,
    horizon,
    steps,
    graph,
    slots,
    remainingMinutesByStepId: indexRemainingMinutes(steps),
    blocks: [],
    warnings: []
  };

  const scheduledState = assignSteps(initialState, comparator);
  const repairedState = repairSchedule(scheduledState, comparator);

  return buildScheduleView(repairedState);
}
```

### 12.2 任务展开

```ts
function buildTaskSteps(taskPool: Task[]): TaskStep[] {
  const steps: TaskStep[] = [];

  for (const task of taskPool) {
    if (task.status === "done" || task.status === "archived") continue;

    if (!task.steps || task.steps.length === 0) {
      steps.push({
        id: task.id,
        taskId: task.id,
        title: task.title,
        durationMinutes: task.durationMinutes,
        minChunkMinutes: task.minChunkMinutes,
        dueAt: task.dueAt,
        value: task.value,
        concurrencyMode: task.concurrencyMode,
        source: "task"
      });
      continue;
    }

    for (const step of task.steps) {
      steps.push({
        id: step.id,
        taskId: task.id,
        title: step.title,
        durationMinutes: step.durationMinutes,
        minChunkMinutes: step.minChunkMinutes,
        dueAt: task.dueAt,
        value: task.value,
        concurrencyMode: task.concurrencyMode,
        source: "task-step"
      });
    }
  }

  return steps;
}
```

### 12.3 依赖图构建

```ts
function buildTaskGraph(taskPool: Task[], steps: TaskStep[]): TaskGraph {
  const links: TaskLink[] = [];
  const taskToStepIds = indexTaskToStepIds(steps);

  for (const task of taskPool) {
    if (task.status === "done" || task.status === "archived") continue;

    for (const dependsOnTaskId of task.dependsOnTaskIds) {
      const fromSteps = taskToStepIds[dependsOnTaskId] ?? [];
      const toSteps = taskToStepIds[task.id] ?? [];

      for (const fromStepId of tailSteps(fromSteps)) {
        for (const toStepId of headSteps(toSteps)) {
          links.push({
            fromStepId,
            toStepId,
            type: "finish-to-start"
          });
        }
      }
    }

    for (const step of task.steps ?? []) {
      for (const prevStepId of step.dependsOnStepIds) {
        links.push({
          fromStepId: prevStepId,
          toStepId: step.id,
          type: "finish-to-start"
        });
      }
    }
  }

  assertDag(steps, links);
  return { steps, links };
}
```

### 12.4 时间槽展开

```ts
function buildTimeSlots(
  timeTemplate: TimeTemplate,
  horizon: { startAt: Date; endAt: Date }
): TimeSlot[] {
  const slots: TimeSlot[] = [];

  for (const day of eachDateInRange(horizon.startAt, horizon.endAt)) {
    for (const range of timeTemplate.weeklyRanges) {
      if (!sameWeekday(day, range.weekday)) continue;

      const startAt = combineDateAndClock(day, range.startTime, timeTemplate.timezone);
      const endAt = combineDateAndClock(day, range.endTime, timeTemplate.timezone);

      if (endAt <= horizon.startAt || startAt >= horizon.endAt) continue;

      slots.push({
        id: buildSlotId(startAt, endAt),
        startAt: startAt.toISOString(),
        endAt: endAt.toISOString(),
        durationMinutes: minutesBetween(startAt, endAt)
      });
    }
  }

  return sortByStartAt(slots);
}
```

### 12.5 可选位置过滤

```ts
function findCandidates(
  step: TaskStep,
  remainingMinutes: number,
  slots: TimeSlot[],
  blocks: ScheduleBlock[],
  graph: TaskGraph
): TimeSlot[] {
  if (!isDependencyReady(step, graph, blocks)) return [];

  return slots.filter((slot) => {
    const freeMinutes = getFreeMinutes(slot, blocks);
    if (freeMinutes < step.minChunkMinutes) return false;
    if (remainingMinutes < step.minChunkMinutes) return false;
    if (wouldOverlap(step, slot, blocks)) return false;
    if (wouldBreakDueAt(step, slot, remainingMinutes)) return false;
    return true;
  });
}
```

### 12.6 启发式装箱

```ts
function assignSteps(state: SchedulerState, comparator: Comparator): SchedulerState {
  const unfinished = new Set(state.steps.map((step) => step.id));

  while (unfinished.size > 0) {
    const readySteps = state.steps
      .filter((step) => unfinished.has(step.id))
      .filter((step) => isDependencyReady(step, state.graph, state.blocks));

    if (readySteps.length === 0) break;

    readySteps.sort((a, b) => comparator.compareSteps(a, b, toComparatorContext(state)));

    let placedAny = false;

    for (const step of readySteps) {
      const remainingMinutes = state.remainingMinutesByStepId[step.id];
      const candidates = findCandidates(
        step,
        remainingMinutes,
        state.slots,
        state.blocks,
        state.graph
      );
      if (candidates.length === 0) continue;

      const slot = pickNextStep(step, candidates, comparator, state);
      if (!slot) continue;

      state = placeStep(step, slot, state);

      if (state.remainingMinutesByStepId[step.id] === 0) {
        unfinished.delete(step.id);
      }

      placedAny = true;
      break;
    }

    if (!placedAny) break;
  }

  for (const stepId of unfinished) {
    state.warnings.push(`step_unscheduled:${stepId}`);
  }

  return state;
}
```

### 12.7 局部修复

```ts
function repairSchedule(state: SchedulerState, comparator: Comparator): SchedulerState {
  for (const warning of state.warnings) {
    const step = getStepFromWarning(warning, state.steps);
    if (!step) continue;

    const lowerValueBlocks = findLowerValueConflicts(step, state, comparator);

    for (const block of lowerValueBlocks) {
      const tentative = tryReplaceBlock(step, block, state, comparator);
      if (tentative) {
        state = tentative;
        break;
      }
    }
  }

  return state;
}
```

局部修复的目的不是追求全局最优，而是减少以下问题：

- 高价值任务被碎片任务挤掉
- 大块任务迟迟排不进去
- 明明有可腾挪空间却被早期贪婪选择锁死

### 12.8 视图构建

```ts
function buildScheduleView(state: SchedulerState): ScheduleView {
  const finishedStepIds = new Set(
    Object.entries(state.remainingMinutesByStepId)
      .filter(([, remainingMinutes]) => remainingMinutes === 0)
      .map(([stepId]) => stepId)
  );

  return {
    horizonStart: state.horizon.startAt.toISOString(),
    horizonEnd: state.horizon.endAt.toISOString(),
    blocks: sortBlocks(state.blocks),
    orderedSteps: sortStepsForView(state.steps, state.blocks),
    unscheduledSteps: state.steps.filter((step) => !finishedStepIds.has(step.id)),
    warnings: dedupeWarnings(state.warnings)
  };
}
```

### 12.9 分块放置原则

`placeStep` 需要支持把同一个步骤拆到多个时间块中，但要满足两个条件：

- 每个时间块都不小于 `minChunkMinutes`
- 最后一个时间块也不能小于 `minChunkMinutes`

因此它的核心不是“把步骤塞进槽里”，而是：

1. 为当前步骤选择一个可行槽位
2. 在槽位中放入一个合法大小的时间块
3. 扣减该步骤的剩余时长
4. 若剩余时长仍大于零，则后续继续为同一步骤找下一个块

伪代码可抽象为：

```ts
function placeStep(step: TaskStep, slot: TimeSlot, state: SchedulerState): SchedulerState {
  const remainingMinutes = state.remainingMinutesByStepId[step.id];
  const freeMinutes = getFreeMinutes(slot, state.blocks);
  const chunkMinutes = chooseChunkMinutes(
    remainingMinutes,
    freeMinutes,
    step.minChunkMinutes
  );

  if (!chunkMinutes) return state;

  const block = buildBlock(step, slot, chunkMinutes, state.blocks);

  state.blocks.push(block);
  state.remainingMinutesByStepId[step.id] -= chunkMinutes;

  return state;
}
```

## 13. 与现有实现的映射

当前仓库中已经存在以下核心类型：

- `Task`
- `TimeSlot`
- `ScheduleBlock`

首轮落地时，不需要一次性推翻现有实现，可以按增量方式映射。

### 13.1 可直接复用的部分

- `Task.minChunkMinutes`
- `TimeSlot.startAt / endAt`
- `ScheduleBlock.taskId / slotId / startAt / endAt`

### 13.2 需要逐步补充的部分

- `Task.value.rewardOnTime`
- `Task.value.penaltyMissed`
- `Task.dependsOnTaskIds`
- `Task.steps`
- `Task.concurrencyMode`

### 13.3 过渡策略

在实现初期，可以先把新增字段临时放入扩展字段中，再逐步提升为正式类型字段。

这样可以避免：

- 一次性大改所有表结构
- 一次性大改所有客户端表单
- 文档模型先行但工程上无法渐进落地

## 14. 结论

这套模型的核心判断是：

- 调度问题本质上是装箱问题
- 装箱前先判硬约束
- 装箱时以总价值最大化为目标
- 任务池是动态变化的，因此调度必须是滚动重算

在结构上，首轮只做必要复杂度：

- 统一任务与子步骤
- 统一任务依赖与步骤依赖
- 把并行和复杂时间价值函数保留为扩展点

这样既能覆盖当前已经识别到的决策因素，也能为后续增强保留稳定骨架。
