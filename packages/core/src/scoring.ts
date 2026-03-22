import type { PlannedTimeSlot, Task } from "./types";

const clamp = (value: number, min: number, max: number): number => Math.max(min, Math.min(max, value));

const slotDurationMinutes = (slot: PlannedTimeSlot): number => {
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

export const scoreTaskForSlot = (task: Task, slot: PlannedTimeSlot): number => {
  const slotMinutes = slotDurationMinutes(slot);
  if (task.minChunkMinutes > slotMinutes) return -1;

  const score =
    dueUrgencyScore(task) * 0.35 +
    clamp(task.scheduleValue.penaltyMissed / 50, 0, 1) * 0.35 +
    clamp(task.scheduleValue.rewardOnTime / 50, 0, 1) * 0.2 +
    clamp(task.minChunkMinutes / Math.max(slotMinutes, 1), 0, 1) * 0.1;

  return Number(score.toFixed(4));
};
