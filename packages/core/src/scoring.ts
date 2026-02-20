import type { Task, TimeSlot } from "./types";

const clamp = (value: number, min: number, max: number): number => Math.max(min, Math.min(max, value));

const isTraitHardMatch = (task: Task, slot: TimeSlot): boolean => {
  const t = task.taskTraits;
  const s = slot.slotTraits;

  if (task.minChunkMinutes > slotDurationMinutes(slot)) return false;
  if (t.location !== "any" && t.location !== s.location) return false;
  if (t.device !== "any" && t.device !== s.device) return false;
  if (t.focus === "high" && s.focus === "low") return false;
  if (t.interruptibility === "low" && s.interruptibility === "high") return false;

  return true;
};

const slotDurationMinutes = (slot: TimeSlot): number => {
  const start = new Date(slot.startAt).getTime();
  const end = new Date(slot.endAt).getTime();
  return Math.max(0, Math.round((end - start) / 60000));
};

const dueUrgencyScore = (task: Task, now = new Date()): number => {
  if (!task.dueAt) return 0.3;
  const due = new Date(task.dueAt).getTime();
  const diffHours = (due - now.getTime()) / 3600000;
  if (diffHours <= 0) return 1;
  if (diffHours <= 24) return 0.9;
  if (diffHours <= 72) return 0.75;
  return 0.4;
};

const focusMatchScore = (task: Task, slot: TimeSlot): number => {
  const mapping = { low: 1, medium: 2, high: 3 } as const;
  const delta = Math.abs(mapping[task.taskTraits.focus] - mapping[slot.slotTraits.focus]);
  return delta === 0 ? 1 : delta === 1 ? 0.6 : 0.2;
};

export const scoreTaskForSlot = (task: Task, slot: TimeSlot): number => {
  if (!isTraitHardMatch(task, slot)) return -1;

  const score =
    dueUrgencyScore(task) * 0.35 +
    clamp(task.importance / 5, 0, 1) * 0.2 +
    clamp(task.value / 5, 0, 1) * 0.15 +
    (1 - clamp(task.postponability / 5, 0, 1)) * 0.1 +
    (1 - clamp(task.difficulty / 5, 0, 1)) * 0.05 +
    focusMatchScore(task, slot) * 0.15;

  return Number(score.toFixed(4));
};
