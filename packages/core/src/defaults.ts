import type {
  ConcurrencyMode,
  Task,
  TaskStepTemplate,
  TaskValueSpec,
  TimeTemplate,
  Weekday,
  WeeklyTimeRange
} from "./types";

export const DEFAULT_MIN_CHUNK_MINUTES = 25;
export const DEFAULT_CONCURRENCY_MODE: ConcurrencyMode = "serial";

export const DEFAULT_TASK_NUMERIC = {
  estimatedMinutes: 30
} as const;

export const DEFAULT_TASK_VALUE: TaskValueSpec = {
  rewardOnTime: 10,
  penaltyMissed: 25
};

const buildRangeId = (weekday: Weekday, startTime: string, endTime: string): string => `${weekday}-${startTime}-${endTime}`;

const defaultWeeklyRanges = (): WeeklyTimeRange[] => {
  const weekdays: Weekday[] = [1, 2, 3, 4, 5];
  const segments = [
    ["09:00", "12:00"],
    ["14:00", "18:00"],
    ["19:00", "20:30"]
  ] as const;

  const ranges: WeeklyTimeRange[] = [];
  for (const weekday of weekdays) {
    for (const [startTime, endTime] of segments) {
      ranges.push({
        id: buildRangeId(weekday, startTime, endTime),
        weekday,
        startTime,
        endTime
      });
    }
  }
  return ranges;
};

export const DEFAULT_TIME_TEMPLATE: TimeTemplate = {
  timezone:
    typeof Intl !== "undefined" ? Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai" : "Asia/Shanghai",
  weeklyRanges: defaultWeeklyRanges()
};

export const nowIso = (): string => new Date().toISOString();

const normalizeNumber = (value: unknown, fallback: number): number => {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
};

const readExt = (extJson: unknown): Record<string, unknown> =>
  typeof extJson === "object" && extJson ? (extJson as Record<string, unknown>) : {};

const readTaskModel = (
  extJson: unknown
): {
  scheduleValue?: TaskValueSpec;
  dependsOnTaskIds?: string[];
  steps?: TaskStepTemplate[];
  concurrencyMode?: ConcurrencyMode;
} => {
  const ext = readExt(extJson);
  const raw = ext.taskModel;
  if (!raw || typeof raw !== "object") return {};

  const model = raw as Record<string, unknown>;
  const scheduleValueRaw = model.scheduleValue;
  const scheduleValue =
    scheduleValueRaw && typeof scheduleValueRaw === "object"
      ? {
          rewardOnTime: normalizeNumber((scheduleValueRaw as Record<string, unknown>).rewardOnTime, DEFAULT_TASK_VALUE.rewardOnTime),
          penaltyMissed: normalizeNumber((scheduleValueRaw as Record<string, unknown>).penaltyMissed, DEFAULT_TASK_VALUE.penaltyMissed)
        }
      : undefined;

  const dependsOnTaskIds = Array.isArray(model.dependsOnTaskIds)
    ? model.dependsOnTaskIds.map((item) => String(item))
    : undefined;

  const steps = Array.isArray(model.steps)
    ? model.steps
        .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
        .map((item, index) => ({
          id: typeof item.id === "string" && item.id.trim() ? item.id.trim() : `step-${index + 1}`,
          title: typeof item.title === "string" && item.title.trim() ? item.title.trim() : `步骤 ${index + 1}`,
          estimatedMinutes: Math.max(1, normalizeNumber(item.estimatedMinutes, DEFAULT_TASK_NUMERIC.estimatedMinutes)),
          minChunkMinutes: Math.max(1, normalizeNumber(item.minChunkMinutes, DEFAULT_MIN_CHUNK_MINUTES)),
          dependsOnStepIds: Array.isArray(item.dependsOnStepIds)
            ? item.dependsOnStepIds.map((stepId) => String(stepId))
            : []
        }))
    : undefined;

  const concurrencyMode = model.concurrencyMode === "serial" ? "serial" : undefined;

  const result: {
    scheduleValue?: TaskValueSpec;
    dependsOnTaskIds?: string[];
    steps?: TaskStepTemplate[];
    concurrencyMode?: ConcurrencyMode;
  } = {};

  if (scheduleValue) result.scheduleValue = scheduleValue;
  if (dependsOnTaskIds) result.dependsOnTaskIds = dependsOnTaskIds;
  if (steps) result.steps = steps;
  if (concurrencyMode) result.concurrencyMode = concurrencyMode;

  return result;
};

export const embedTaskModel = (task: Task): Record<string, unknown> => {
  const ext = readExt(task.extJson);
  const existingModel = readExt(ext.taskModel);

  return {
    ...ext,
    taskModel: {
      ...existingModel,
      scheduleValue: task.scheduleValue,
      dependsOnTaskIds: task.dependsOnTaskIds,
      steps: task.steps,
      concurrencyMode: task.concurrencyMode
    }
  };
};

const normalizeTaskSteps = (steps: TaskStepTemplate[] | undefined, fallbackMinutes: number, fallbackChunk: number): TaskStepTemplate[] => {
  if (!steps || steps.length === 0) return [];

  return steps.map((step, index) => ({
    id: step.id.trim() || `step-${index + 1}`,
    title: step.title.trim() || `步骤 ${index + 1}`,
    estimatedMinutes: Math.max(1, normalizeNumber(step.estimatedMinutes, fallbackMinutes)),
    minChunkMinutes: Math.max(1, normalizeNumber(step.minChunkMinutes, fallbackChunk)),
    dependsOnStepIds: step.dependsOnStepIds.filter(Boolean)
  }));
};

export const makeTask = (input: Pick<Task, "id" | "title" | "rawInput"> & Partial<Task>): Task => {
  const now = nowIso();
  const extModel = readTaskModel(input.extJson);
  const estimatedMinutes = Math.max(
    1,
    normalizeNumber(input.estimatedMinutes, DEFAULT_TASK_NUMERIC.estimatedMinutes)
  );
  const minChunkMinutes = Math.max(
    1,
    normalizeNumber(input.minChunkMinutes, DEFAULT_MIN_CHUNK_MINUTES)
  );

  const scheduleValue = input.scheduleValue ?? extModel.scheduleValue ?? DEFAULT_TASK_VALUE;
  const dependsOnTaskIds = input.dependsOnTaskIds ?? extModel.dependsOnTaskIds ?? [];
  const rawSteps = input.steps ?? extModel.steps ?? [];
  const steps = normalizeTaskSteps(rawSteps, estimatedMinutes, minChunkMinutes);
  const concurrencyMode = input.concurrencyMode ?? extModel.concurrencyMode ?? DEFAULT_CONCURRENCY_MODE;

  const task: Task = {
    id: input.id,
    title: input.title,
    rawInput: input.rawInput,
    description: input.description,
    status: input.status ?? "todo",
    estimatedMinutes,
    minChunkMinutes,
    dueAt: input.dueAt,
    tags: input.tags ?? [],
    scheduleValue: {
      rewardOnTime: Math.max(0, normalizeNumber(scheduleValue.rewardOnTime, DEFAULT_TASK_VALUE.rewardOnTime)),
      penaltyMissed: Math.max(0, normalizeNumber(scheduleValue.penaltyMissed, DEFAULT_TASK_VALUE.penaltyMissed))
    },
    dependsOnTaskIds,
    steps,
    concurrencyMode,
    createdAt: input.createdAt ?? now,
    updatedAt: input.updatedAt ?? now,
    extJson: {}
  };

  task.extJson = embedTaskModel({
    ...task,
    extJson: input.extJson ?? {}
  });

  return task;
};
