import { makeTask } from "./defaults";
import { parseQuickInput } from "./nlp";
import { createDefaultComparator, refreshSchedule } from "./scheduler";
import type { ScheduleBlock, ScheduleView, Task, TimeTemplate, WeeklyTimeRange } from "./types";

export interface HorizonOption {
  label: string;
  compactLabel: string;
  days: number;
}

export interface WeekdayOption {
  value: WeeklyTimeRange["weekday"];
  label: string;
}

export interface DayBlockGroup {
  dayKey: string;
  blocks: ScheduleBlock[];
}

export const HORIZON_OPTIONS: HorizonOption[] = [
  { label: "1 天", compactLabel: "1天", days: 1 },
  { label: "7 天", compactLabel: "7天", days: 7 },
  { label: "21 天", compactLabel: "21天", days: 21 },
  { label: "42 天", compactLabel: "42天", days: 42 }
];

export const WEEKDAY_OPTIONS: WeekdayOption[] = [
  { value: 1, label: "周一" },
  { value: 2, label: "周二" },
  { value: 3, label: "周三" },
  { value: 4, label: "周四" },
  { value: 5, label: "周五" },
  { value: 6, label: "周六" },
  { value: 7, label: "周日" }
];

export const addDays = (source: Date, days: number): Date => {
  const next = new Date(source);
  next.setDate(next.getDate() + days);
  return next;
};

export const formatScheduleDay = (source: string, locale = "zh-CN"): string =>
  new Date(source).toLocaleDateString(locale, { month: "short", day: "numeric", weekday: "short" });

export const formatScheduleClock = (source: string, locale = "zh-CN"): string =>
  new Date(source).toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit", hour12: false });

export const groupScheduleBlocksByDay = (blocks: ScheduleBlock[]): DayBlockGroup[] => {
  const grouped = new Map<string, ScheduleBlock[]>();

  for (const block of blocks) {
    const dayKey = block.startAt.slice(0, 10);
    const list = grouped.get(dayKey) ?? [];
    list.push(block);
    grouped.set(dayKey, list);
  }

  return [...grouped.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([dayKey, dayBlocks]) => ({
      dayKey,
      blocks: dayBlocks.sort((a, b) => a.startAt.localeCompare(b.startAt))
    }));
};

export const buildSchedulePresentation = (
  tasks: Task[],
  template: TimeTemplate,
  horizonDays: number,
  now = new Date()
): {
  horizonEnd: Date;
  scheduleView: ScheduleView;
  blocksByDay: DayBlockGroup[];
} => {
  const horizonEnd = addDays(now, horizonDays);
  const scheduleView = refreshSchedule(tasks, template, now, horizonEnd, createDefaultComparator());

  return {
    horizonEnd,
    scheduleView,
    blocksByDay: groupScheduleBlocksByDay(scheduleView.blocks)
  };
};

export const buildQuickTask = (id: string, rawInput: string): Task => {
  const parsed = parseQuickInput(rawInput.trim());
  return makeTask({
    id,
    title: parsed.title,
    rawInput: rawInput.trim(),
    estimatedMinutes: parsed.estimatedMinutes,
    minChunkMinutes: parsed.minChunkMinutes,
    dueAt: parsed.dueAt,
    tags: parsed.tags
  });
};

export const describeTaskMeta = (task: Task): string =>
  `估时 ${task.estimatedMinutes}m | 最小块 ${task.minChunkMinutes}m | 奖励 ${task.scheduleValue.rewardOnTime} | 损失 ${task.scheduleValue.penaltyMissed}`;
