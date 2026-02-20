import type { Task, TaskTraits } from "./types";

export const DEFAULT_MIN_CHUNK_MINUTES = 25;

export const DEFAULT_TASK_TRAITS: TaskTraits = {
  focus: "medium",
  interruptibility: "medium",
  location: "any",
  device: "any",
  parallelizable: false
};

export const DEFAULT_TASK_NUMERIC = {
  estimatedMinutes: 30,
  importance: 3,
  value: 3,
  difficulty: 3,
  postponability: 3
} as const;

export const nowIso = (): string => new Date().toISOString();

export const makeTask = (
  input: Pick<Task, "id" | "title" | "rawInput"> & Partial<Task>
): Task => {
  const now = nowIso();
  return {
    id: input.id,
    title: input.title,
    rawInput: input.rawInput,
    description: input.description,
    status: input.status ?? "todo",
    estimatedMinutes: input.estimatedMinutes ?? DEFAULT_TASK_NUMERIC.estimatedMinutes,
    minChunkMinutes: input.minChunkMinutes ?? DEFAULT_MIN_CHUNK_MINUTES,
    dueAt: input.dueAt,
    importance: input.importance ?? DEFAULT_TASK_NUMERIC.importance,
    value: input.value ?? DEFAULT_TASK_NUMERIC.value,
    difficulty: input.difficulty ?? DEFAULT_TASK_NUMERIC.difficulty,
    postponability: input.postponability ?? DEFAULT_TASK_NUMERIC.postponability,
    taskTraits: input.taskTraits ?? DEFAULT_TASK_TRAITS,
    tags: input.tags ?? [],
    createdAt: input.createdAt ?? now,
    updatedAt: input.updatedAt ?? now,
    extJson: input.extJson ?? {}
  };
};
