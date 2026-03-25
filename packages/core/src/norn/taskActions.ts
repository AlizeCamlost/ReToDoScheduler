import { nowIso } from "../defaults";
import type { Task, TaskStatus, TaskStepProgress, TaskStepTemplate } from "../types";
import { getNornSequenceRank, withNornSequenceRank } from "./taskOrder";

export type NornTaskStepProgressState = "completed" | "current" | "upcoming";

const isStepCompleted = (step: TaskStepTemplate): boolean => Boolean(step.progress?.completedAt);

const withStepProgress = (step: TaskStepTemplate, progress: TaskStepProgress | undefined): TaskStepTemplate => ({
  ...step,
  progress
});

const ensureCurrentStepStarted = (task: Task, updatedAt: string): Task => {
  const currentStepIndex = getCurrentTaskStepIndex(task);
  if (currentStepIndex === null) return task;

  const currentStep = task.steps[currentStepIndex];
  if (!currentStep) return task;

  return {
    ...task,
    steps: task.steps.map((step, index) =>
      index === currentStepIndex
        ? withStepProgress(step, {
            startedAt: currentStep.progress?.startedAt ?? updatedAt,
            completedAt: undefined
          })
        : step
    )
  };
};

export const getCurrentTaskStepIndex = (task: Task): number | null => {
  const index = task.steps.findIndex((step) => !isStepCompleted(step));
  return index >= 0 ? index : null;
};

export const getCurrentTaskStep = (task: Task): TaskStepTemplate | null => {
  const index = getCurrentTaskStepIndex(task);
  return index === null ? null : task.steps[index] ?? null;
};

export const getTaskStepProgressState = (task: Task, stepId: string): NornTaskStepProgressState | null => {
  const stepIndex = task.steps.findIndex((step) => step.id === stepId);
  if (stepIndex < 0) return null;
  const step = task.steps[stepIndex];
  if (!step) return null;
  if (isStepCompleted(step)) return "completed";

  const currentStepIndex = getCurrentTaskStepIndex(task);
  return currentStepIndex === stepIndex ? "current" : "upcoming";
};

export const setTaskStatus = (task: Task, status: TaskStatus, updatedAt = nowIso()): Task => {
  let nextTask: Task = {
    ...task,
    status,
    updatedAt
  };

  switch (status) {
    case "todo":
      nextTask = {
        ...nextTask,
        steps: nextTask.steps.map((step) => withStepProgress(step, undefined))
      };
      break;
    case "doing": {
      const allStepsCompleted = nextTask.steps.length > 0 && nextTask.steps.every(isStepCompleted);
      if (allStepsCompleted) {
        nextTask = {
          ...nextTask,
          steps: nextTask.steps.map((step) => withStepProgress(step, undefined))
        };
      }
      nextTask = ensureCurrentStepStarted(nextTask, updatedAt);
      break;
    }
    case "done":
      nextTask = {
        ...nextTask,
        steps: nextTask.steps.map((step) =>
          withStepProgress(step, {
            startedAt: step.progress?.startedAt ?? updatedAt,
            completedAt: updatedAt
          })
        )
      };
      break;
    case "archived":
      break;
  }

  return nextTask;
};

export const appendTaskStep = (task: Task, title: string, updatedAt = nowIso()): Task => {
  const normalizedTitle = title.trim();
  if (!normalizedTitle) return task;

  const existingIds = new Set(task.steps.map((step) => step.id));
  const baseId =
    normalizedTitle
      .toLowerCase()
      .replace(/[^\w\u4e00-\u9fa5-]+/g, "-")
      .replace(/^-+|-+$/g, "") || `step-${task.steps.length + 1}`;

  let nextId = baseId;
  for (let suffix = 2; existingIds.has(nextId); suffix += 1) {
    nextId = `${baseId}-${suffix}`;
  }

  const stepMinutes = Math.max(task.minChunkMinutes, Math.min(30, task.estimatedMinutes));
  let nextStep: TaskStepTemplate = {
    id: nextId,
    title: normalizedTitle,
    estimatedMinutes: stepMinutes,
    minChunkMinutes: Math.min(task.minChunkMinutes, stepMinutes),
    dependsOnStepIds: task.steps.length > 0 && task.steps[task.steps.length - 1] ? [task.steps[task.steps.length - 1]!.id] : []
  };

  if ((task.status === "doing" && getCurrentTaskStep(task) === null) || task.status === "done") {
    nextStep = withStepProgress(nextStep, { startedAt: updatedAt });
  }

  return {
    ...task,
    status: task.status === "done" ? "doing" : task.status,
    updatedAt,
    steps: [...task.steps, nextStep]
  };
};

export const completeTaskStep = (task: Task, stepId: string, updatedAt = nowIso()): Task | null => {
  const currentStepIndex = getCurrentTaskStepIndex(task);
  if (currentStepIndex === null || task.steps[currentStepIndex]?.id !== stepId) {
    return null;
  }

  const steps = task.steps.map((step, index) => {
    if (index !== currentStepIndex) return step;
    return withStepProgress(step, {
      startedAt: step.progress?.startedAt ?? updatedAt,
      completedAt: updatedAt
    });
  });

  const nextStepIndex = steps.findIndex((step, index) => index > currentStepIndex && !isStepCompleted(step));
  const progressedSteps =
    nextStepIndex < 0
      ? steps
      : steps.map((step, index) =>
          index === nextStepIndex
            ? withStepProgress(step, {
                startedAt: step.progress?.startedAt ?? updatedAt,
                completedAt: step.progress?.completedAt
              })
            : step
        );

  return {
    ...task,
    status: progressedSteps.length > 0 && progressedSteps.every(isStepCompleted) ? "done" : "doing",
    updatedAt,
    steps: progressedSteps
  };
};

export const reorderTasksForSequence = (tasks: Task[], primaryTaskIds: string[], updatedAt = nowIso()): Task[] => {
  const activeTasks = tasks.filter((task) => task.status === "todo" || task.status === "doing");
  if (activeTasks.length === 0) return tasks;

  const activeTaskIds = new Set(activeTasks.map((task) => task.id));
  const orderedTaskIds: string[] = [];
  const seen = new Set<string>();

  for (const taskId of primaryTaskIds) {
    if (activeTaskIds.has(taskId) && !seen.has(taskId)) {
      seen.add(taskId);
      orderedTaskIds.push(taskId);
    }
  }

  for (const task of activeTasks) {
    if (!seen.has(task.id)) {
      seen.add(task.id);
      orderedTaskIds.push(task.id);
    }
  }

  const rankByTaskId = new Map(orderedTaskIds.map((taskId, index) => [taskId, index]));

  return tasks.map((task) => {
    const rank = rankByTaskId.get(task.id);
    if (rank === undefined) return task;
    if (getNornSequenceRank(task) === rank) return task;
    return {
      ...withNornSequenceRank(task, rank),
      updatedAt
    };
  });
};
