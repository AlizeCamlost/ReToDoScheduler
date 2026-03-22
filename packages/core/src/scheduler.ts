import { DEFAULT_TIME_TEMPLATE } from "./defaults";
import type {
  Comparator,
  ComparatorContext,
  OrderedTaskStep,
  PlannedTimeSlot,
  ScheduleBlock,
  ScheduleView,
  ScheduleWarning,
  Task,
  TaskGraph,
  TaskLink,
  TaskStep,
  TimeTemplate,
  WeeklyTimeRange
} from "./types";

interface SchedulerState {
  now: Date;
  horizonStart: Date;
  horizonEnd: Date;
  steps: TaskStep[];
  graph: TaskGraph;
  slots: PlannedTimeSlot[];
  remainingMinutesByStepId: Record<string, number>;
  blocks: ScheduleBlock[];
  warnings: ScheduleWarning[];
}

const minutesBetween = (startAt: Date, endAt: Date): number => Math.max(0, Math.round((endAt.getTime() - startAt.getTime()) / 60000));

const addMinutes = (source: Date, minutes: number): Date => new Date(source.getTime() + minutes * 60000);

const parseClock = (clock: string): { hours: number; minutes: number } => {
  const [hours, minutes] = clock.split(":");
  return {
    hours: Number(hours ?? 0),
    minutes: Number(minutes ?? 0)
  };
};

const getWeekday = (source: Date): WeeklyTimeRange["weekday"] => {
  const day = source.getDay();
  return (day === 0 ? 7 : day) as WeeklyTimeRange["weekday"];
};

const toDateOnly = (source: Date): Date => new Date(source.getFullYear(), source.getMonth(), source.getDate());

const sortSlots = (slots: PlannedTimeSlot[]): PlannedTimeSlot[] =>
  [...slots].sort((a, b) => new Date(a.startAt).getTime() - new Date(b.startAt).getTime());

const getBlockMinutes = (block: ScheduleBlock): number => minutesBetween(new Date(block.startAt), new Date(block.endAt));

const buildStepId = (taskId: string, stepId?: string): string => (stepId ? `task:${taskId}/step:${stepId}` : `task:${taskId}`);

const getComparatorContext = (now: Date, horizonStart: Date, horizonEnd: Date): ComparatorContext => ({
  now: now.toISOString(),
  horizonStart: horizonStart.toISOString(),
  horizonEnd: horizonEnd.toISOString()
});

const getDueTime = (step: TaskStep): number => (step.dueAt ? new Date(step.dueAt).getTime() : Number.POSITIVE_INFINITY);

export const createDefaultComparator = (): Comparator => ({
  compareSteps(a, b) {
    if (a.penaltyMissed !== b.penaltyMissed) return b.penaltyMissed - a.penaltyMissed;

    const dueDiff = getDueTime(a) - getDueTime(b);
    if (Number.isFinite(dueDiff) && dueDiff !== 0) return dueDiff;

    if (a.minChunkMinutes !== b.minChunkMinutes) return b.minChunkMinutes - a.minChunkMinutes;
    if (a.rewardOnTime !== b.rewardOnTime) return b.rewardOnTime - a.rewardOnTime;

    return new Date(a.updatedAt).getTime() - new Date(b.updatedAt).getTime();
  },
  scoreCandidate(step, slot) {
    const dueTime = getDueTime(step);
    const slotStart = new Date(slot.startAt).getTime();
    const slotEnd = new Date(slot.endAt).getTime();
    const dueSlack = Number.isFinite(dueTime) ? Math.max(0, dueTime - slotEnd) / 60000 : 10_000;

    return (
      step.penaltyMissed * 10 +
      step.rewardOnTime * 2 +
      step.minChunkMinutes -
      dueSlack * 0.01 -
      slotStart * 0.0000000001
    );
  }
});

export const normalizeTimeTemplate = (template?: TimeTemplate | undefined): TimeTemplate => {
  if (!template || !Array.isArray(template.weeklyRanges) || template.weeklyRanges.length === 0) {
    return DEFAULT_TIME_TEMPLATE;
  }

  return {
    timezone: template.timezone || DEFAULT_TIME_TEMPLATE.timezone,
    weeklyRanges: template.weeklyRanges
      .filter((range) => range.startTime < range.endTime)
      .map((range) => ({
        id: range.id,
        weekday: range.weekday,
        startTime: range.startTime,
        endTime: range.endTime
      }))
  };
};

export const buildTimeSlots = (
  template: TimeTemplate,
  horizonStart: Date,
  horizonEnd: Date
): PlannedTimeSlot[] => {
  const normalized = normalizeTimeTemplate(template);
  const slots: PlannedTimeSlot[] = [];

  for (
    let cursor = toDateOnly(horizonStart);
    cursor.getTime() <= horizonEnd.getTime();
    cursor = addMinutes(cursor, 24 * 60)
  ) {
    const weekday = getWeekday(cursor);
    const dayRanges = normalized.weeklyRanges.filter((range) => range.weekday === weekday);

    for (const range of dayRanges) {
      const startClock = parseClock(range.startTime);
      const endClock = parseClock(range.endTime);
      const startAt = new Date(
        cursor.getFullYear(),
        cursor.getMonth(),
        cursor.getDate(),
        startClock.hours,
        startClock.minutes
      );
      const endAt = new Date(
        cursor.getFullYear(),
        cursor.getMonth(),
        cursor.getDate(),
        endClock.hours,
        endClock.minutes
      );

      if (endAt <= horizonStart || startAt >= horizonEnd) continue;

      slots.push({
        id: `${range.id}-${startAt.toISOString()}`,
        startAt: startAt.toISOString(),
        endAt: endAt.toISOString(),
        durationMinutes: minutesBetween(startAt, endAt)
      });
    }
  }

  return sortSlots(slots);
};

export const buildTaskSteps = (tasks: Task[]): TaskStep[] => {
  const steps: TaskStep[] = [];

  for (const task of tasks) {
    if (task.status === "done" || task.status === "archived") continue;

    if (task.steps.length === 0) {
      steps.push({
        id: buildStepId(task.id),
        taskId: task.id,
        taskTitle: task.title,
        title: task.title,
        estimatedMinutes: task.estimatedMinutes,
        minChunkMinutes: task.minChunkMinutes,
        dueAt: task.dueAt,
        rewardOnTime: task.scheduleValue.rewardOnTime,
        penaltyMissed: task.scheduleValue.penaltyMissed,
        dependsOnStepIds: [],
        concurrencyMode: task.concurrencyMode,
        source: "task",
        updatedAt: task.updatedAt
      });
      continue;
    }

    const localToReal = new Map<string, string>();
    for (const step of task.steps) {
      localToReal.set(step.id, buildStepId(task.id, step.id));
    }

    for (const step of task.steps) {
      steps.push({
        id: localToReal.get(step.id) ?? buildStepId(task.id, step.id),
        taskId: task.id,
        taskTitle: task.title,
        title: step.title,
        estimatedMinutes: step.estimatedMinutes,
        minChunkMinutes: step.minChunkMinutes,
        dueAt: task.dueAt,
        rewardOnTime: task.scheduleValue.rewardOnTime,
        penaltyMissed: task.scheduleValue.penaltyMissed,
        dependsOnStepIds: step.dependsOnStepIds
          .map((dependencyId) => localToReal.get(dependencyId))
          .filter((dependencyId): dependencyId is string => Boolean(dependencyId)),
        concurrencyMode: task.concurrencyMode,
        source: "task-step",
        updatedAt: task.updatedAt
      });
    }
  }

  return steps;
};

export const buildTaskGraph = (tasks: Task[], steps: TaskStep[]): TaskGraph => {
  const links: TaskLink[] = [];
  const stepsByTask = new Map<string, TaskStep[]>();

  for (const step of steps) {
    const list = stepsByTask.get(step.taskId) ?? [];
    list.push(step);
    stepsByTask.set(step.taskId, list);

    for (const dependencyId of step.dependsOnStepIds) {
      links.push({
        fromStepId: dependencyId,
        toStepId: step.id,
        type: "finish-to-start"
      });
    }
  }

  const headsByTask = new Map<string, string[]>();
  const tailsByTask = new Map<string, string[]>();

  for (const task of tasks) {
    const taskSteps = stepsByTask.get(task.id) ?? [];
    if (taskSteps.length === 0) continue;

    const inCount = new Map<string, number>();
    const outCount = new Map<string, number>();

    for (const step of taskSteps) {
      inCount.set(step.id, 0);
      outCount.set(step.id, 0);
    }

    for (const link of links) {
      if (!taskSteps.some((step) => step.id === link.fromStepId) || !taskSteps.some((step) => step.id === link.toStepId)) continue;
      inCount.set(link.toStepId, (inCount.get(link.toStepId) ?? 0) + 1);
      outCount.set(link.fromStepId, (outCount.get(link.fromStepId) ?? 0) + 1);
    }

    headsByTask.set(
      task.id,
      taskSteps.filter((step) => (inCount.get(step.id) ?? 0) === 0).map((step) => step.id)
    );
    tailsByTask.set(
      task.id,
      taskSteps.filter((step) => (outCount.get(step.id) ?? 0) === 0).map((step) => step.id)
    );
  }

  for (const task of tasks) {
    const heads = headsByTask.get(task.id) ?? [];
    if (heads.length === 0) continue;

    for (const dependsOnTaskId of task.dependsOnTaskIds) {
      const tails = tailsByTask.get(dependsOnTaskId) ?? [];
      for (const tail of tails) {
        for (const head of heads) {
          links.push({
            fromStepId: tail,
            toStepId: head,
            type: "finish-to-start"
          });
        }
      }
    }
  }

  return {
    steps,
    links
  };
};

const detectCycle = (graph: TaskGraph): boolean => {
  const inDegree = new Map<string, number>();
  const outgoing = new Map<string, string[]>();

  for (const step of graph.steps) {
    inDegree.set(step.id, 0);
    outgoing.set(step.id, []);
  }

  for (const link of graph.links) {
    inDegree.set(link.toStepId, (inDegree.get(link.toStepId) ?? 0) + 1);
    const next = outgoing.get(link.fromStepId) ?? [];
    next.push(link.toStepId);
    outgoing.set(link.fromStepId, next);
  }

  const queue = [...inDegree.entries()].filter(([, degree]) => degree === 0).map(([stepId]) => stepId);
  let visited = 0;

  while (queue.length > 0) {
    const current = queue.shift();
    if (!current) continue;
    visited += 1;

    for (const target of outgoing.get(current) ?? []) {
      const nextDegree = (inDegree.get(target) ?? 0) - 1;
      inDegree.set(target, nextDegree);
      if (nextDegree === 0) queue.push(target);
    }
  }

  return visited !== graph.steps.length;
};

const getUsedMinutes = (slotId: string, blocks: ScheduleBlock[]): number =>
  blocks.filter((block) => block.slotId === slotId).reduce((sum, block) => sum + getBlockMinutes(block), 0);

const getTailStart = (slot: PlannedTimeSlot, blocks: ScheduleBlock[]): Date => {
  const usedMinutes = getUsedMinutes(slot.id, blocks);
  return addMinutes(new Date(slot.startAt), usedMinutes);
};

const getLastBlockEnd = (stepId: string, blocks: ScheduleBlock[]): Date | null => {
  let lastEnd: Date | null = null;
  for (const block of blocks) {
    if (block.stepId !== stepId) continue;
    const endAt = new Date(block.endAt);
    if (!lastEnd || endAt > lastEnd) {
      lastEnd = endAt;
    }
  }
  return lastEnd;
};

const getCompletedAt = (stepId: string, state: SchedulerState): Date | null => {
  if ((state.remainingMinutesByStepId[stepId] ?? 0) > 0) return null;
  return getLastBlockEnd(stepId, state.blocks);
};

const getDependencyReadyAt = (step: TaskStep, state: SchedulerState): Date | null => {
  let readyAt = state.horizonStart;

  for (const dependencyId of step.dependsOnStepIds) {
    const completedAt = getCompletedAt(dependencyId, state);
    if (!completedAt) return null;
    if (completedAt > readyAt) readyAt = completedAt;
  }

  const ownLastEnd = getLastBlockEnd(step.id, state.blocks);
  if (ownLastEnd && ownLastEnd > readyAt) readyAt = ownLastEnd;

  return readyAt;
};

const getAvailableMinutesInSlot = (slot: PlannedTimeSlot, state: SchedulerState): number =>
  Math.max(0, slot.durationMinutes - getUsedMinutes(slot.id, state.blocks));

const canStillFinishBeforeDue = (
  step: TaskStep,
  state: SchedulerState,
  fromSlotIndex: number,
  readyAt: Date,
  remainingMinutes: number
): boolean => {
  if (!step.dueAt) return true;
  const dueAt = new Date(step.dueAt);
  let capacity = 0;

  for (let index = fromSlotIndex; index < state.slots.length; index += 1) {
    const slot = state.slots[index];
    if (!slot) continue;

    const tailStart = getTailStart(slot, state.blocks);
    const usableStart = tailStart > readyAt ? tailStart : readyAt;
    const slotEnd = new Date(slot.endAt);

    if (usableStart >= slotEnd || usableStart >= dueAt) continue;

    const usableEnd = slotEnd < dueAt ? slotEnd : dueAt;
    capacity += minutesBetween(usableStart, usableEnd);
    if (capacity >= remainingMinutes) return true;
  }

  return false;
};

const canPlaceChunk = (
  step: TaskStep,
  slot: PlannedTimeSlot,
  slotIndex: number,
  state: SchedulerState
): { readyAt: Date; freeMinutes: number } | null => {
  const remainingMinutes = state.remainingMinutesByStepId[step.id] ?? 0;
  if (remainingMinutes <= 0) return null;
  if (step.concurrencyMode && step.concurrencyMode !== "serial") return null;

  const readyAt = getDependencyReadyAt(step, state);
  if (!readyAt) return null;

  const tailStart = getTailStart(slot, state.blocks);
  if (readyAt.getTime() > tailStart.getTime()) return null;

  const freeMinutes = getAvailableMinutesInSlot(slot, state);
  if (freeMinutes < step.minChunkMinutes) return null;
  if (!canStillFinishBeforeDue(step, state, slotIndex, readyAt, remainingMinutes)) return null;

  return { readyAt, freeMinutes };
};

const chooseChunkMinutes = (remainingMinutes: number, freeMinutes: number, minChunkMinutes: number): number | null => {
  let chunkMinutes = Math.min(remainingMinutes, freeMinutes);
  if (chunkMinutes < minChunkMinutes) return null;

  const remainder = remainingMinutes - chunkMinutes;
  if (remainder === 0 || remainder >= minChunkMinutes) return chunkMinutes;

  chunkMinutes -= minChunkMinutes - remainder;
  return chunkMinutes >= minChunkMinutes ? chunkMinutes : null;
};

const buildBlock = (step: TaskStep, slot: PlannedTimeSlot, chunkMinutes: number, blocks: ScheduleBlock[]): ScheduleBlock => {
  const tailStart = getTailStart(slot, blocks);
  const endAt = addMinutes(tailStart, chunkMinutes);

  return {
    id: `${step.id}:${slot.id}:${tailStart.toISOString()}`,
    taskId: step.taskId,
    stepId: step.id,
    slotId: slot.id,
    startAt: tailStart.toISOString(),
    endAt: endAt.toISOString(),
    isParallel: false
  };
};

const compareUnscheduled = (a: OrderedTaskStep, b: OrderedTaskStep): number => {
  if (a.penaltyMissed !== b.penaltyMissed) return b.penaltyMissed - a.penaltyMissed;
  const dueDiff =
    (a.dueAt ? new Date(a.dueAt).getTime() : Number.POSITIVE_INFINITY) -
    (b.dueAt ? new Date(b.dueAt).getTime() : Number.POSITIVE_INFINITY);
  if (Number.isFinite(dueDiff) && dueDiff !== 0) return dueDiff;
  return a.title.localeCompare(b.title, "zh-CN");
};

const buildOrderedStep = (step: TaskStep, state: SchedulerState): OrderedTaskStep => {
  const plannedMinutes = state.blocks
    .filter((block) => block.stepId === step.id)
    .reduce((sum, block) => sum + getBlockMinutes(block), 0);

  return {
    stepId: step.id,
    taskId: step.taskId,
    taskTitle: step.taskTitle,
    title: step.title,
    dueAt: step.dueAt,
    plannedMinutes,
    remainingMinutes: state.remainingMinutesByStepId[step.id] ?? step.estimatedMinutes,
    rewardOnTime: step.rewardOnTime,
    penaltyMissed: step.penaltyMissed,
    source: step.source,
    dependsOnStepIds: step.dependsOnStepIds
  };
};

const buildScheduleView = (state: SchedulerState): ScheduleView => {
  const ordered = state.steps.map((step) => buildOrderedStep(step, state));

  const scheduled = ordered
    .filter((step) => step.plannedMinutes > 0)
    .sort((a, b) => {
      const firstA = state.blocks.find((block) => block.stepId === a.stepId)?.startAt ?? a.dueAt ?? state.horizonEnd.toISOString();
      const firstB = state.blocks.find((block) => block.stepId === b.stepId)?.startAt ?? b.dueAt ?? state.horizonEnd.toISOString();
      return new Date(firstA).getTime() - new Date(firstB).getTime();
    });

  const unscheduled = ordered.filter((step) => step.remainingMinutes > 0).sort(compareUnscheduled);

  return {
    horizonStart: state.horizonStart.toISOString(),
    horizonEnd: state.horizonEnd.toISOString(),
    slots: state.slots,
    blocks: [...state.blocks].sort((a, b) => new Date(a.startAt).getTime() - new Date(b.startAt).getTime()),
    orderedSteps: [...scheduled, ...unscheduled],
    unscheduledSteps: unscheduled,
    warnings: state.warnings
  };
};

export const refreshSchedule = (
  tasks: Task[],
  template: TimeTemplate | undefined,
  now: Date,
  horizonEnd: Date,
  comparator: Comparator = createDefaultComparator()
): ScheduleView => {
  const horizonStart = now;
  const normalizedTemplate = normalizeTimeTemplate(template);
  const steps = buildTaskSteps(tasks);
  const graph = buildTaskGraph(tasks, steps);
  const slots = buildTimeSlots(normalizedTemplate, horizonStart, horizonEnd);

  const baseState: SchedulerState = {
    now,
    horizonStart,
    horizonEnd,
    steps,
    graph,
    slots,
    remainingMinutesByStepId: Object.fromEntries(steps.map((step) => [step.id, step.estimatedMinutes])),
    blocks: [],
    warnings: []
  };

  if (detectCycle(graph)) {
    const ordered = steps.map((step) => ({
      stepId: step.id,
      taskId: step.taskId,
      taskTitle: step.taskTitle,
      title: step.title,
      dueAt: step.dueAt,
      plannedMinutes: 0,
      remainingMinutes: step.estimatedMinutes,
      rewardOnTime: step.rewardOnTime,
      penaltyMissed: step.penaltyMissed,
      source: step.source,
      dependsOnStepIds: step.dependsOnStepIds
    }));

    return {
      horizonStart: horizonStart.toISOString(),
      horizonEnd: horizonEnd.toISOString(),
      slots,
      blocks: [],
      orderedSteps: ordered,
      unscheduledSteps: ordered,
      warnings: [
        {
          code: "dependency-cycle",
          severity: "danger",
          message: "检测到循环依赖，当前无法生成调度视图。"
        }
      ]
    };
  }

  const context = getComparatorContext(now, horizonStart, horizonEnd);
  const unfinished = new Set(steps.map((step) => step.id));
  let state = baseState;

  while (unfinished.size > 0) {
    const readySteps = state.steps
      .filter((step) => unfinished.has(step.id))
      .filter((step) => getDependencyReadyAt(step, state) !== null)
      .sort((a, b) => comparator.compareSteps(a, b, context));

    if (readySteps.length === 0) break;

    let placedAny = false;

    for (const step of readySteps) {
      const candidates = state.slots
        .map((slot, index) => ({
          slot,
          index,
          candidate: canPlaceChunk(step, slot, index, state)
        }))
        .filter((entry): entry is { slot: PlannedTimeSlot; index: number; candidate: { readyAt: Date; freeMinutes: number } } => entry.candidate !== null)
        .sort((a, b) => comparator.scoreCandidate(step, b.slot, context) - comparator.scoreCandidate(step, a.slot, context));

      if (candidates.length === 0) continue;

      const best = candidates[0];
      if (!best) continue;

      const remainingMinutes = state.remainingMinutesByStepId[step.id] ?? 0;
      const chunkMinutes = chooseChunkMinutes(remainingMinutes, best.candidate.freeMinutes, step.minChunkMinutes);
      if (!chunkMinutes) continue;

      const block = buildBlock(step, best.slot, chunkMinutes, state.blocks);
      state = {
        ...state,
        blocks: [...state.blocks, block],
        remainingMinutesByStepId: {
          ...state.remainingMinutesByStepId,
          [step.id]: remainingMinutes - chunkMinutes
        }
      };

      if ((state.remainingMinutesByStepId[step.id] ?? 0) === 0) {
        unfinished.delete(step.id);
      }

      placedAny = true;
      break;
    }

    if (!placedAny) break;
  }

  for (const stepId of unfinished) {
    const step = state.steps.find((item) => item.id === stepId);
    if (!step) continue;

    state.warnings.push({
      code: "unscheduled",
      severity: step.dueAt ? "danger" : "warning",
      taskId: step.taskId,
      stepId: step.id,
      message: step.dueAt
        ? `${step.taskTitle} / ${step.title} 在当前时间窗口内无法于截止前排入。`
        : `${step.taskTitle} / ${step.title} 在当前时间窗口内未排入。`
    });
  }

  if (state.warnings.length > 0 && state.blocks.length === 0 && state.steps.length > 0) {
    state.warnings.unshift({
      code: "capacity",
      severity: "warning",
      message: "当前观察窗口容量不足，调度器只生成了部分或空视图。"
    });
  }

  return buildScheduleView(state);
};
