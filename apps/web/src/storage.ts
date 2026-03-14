import { DEFAULT_TIME_TEMPLATE, type Task, type TimeTemplate } from "@retodo/core";

let sessionDeviceId: string | null = null;

const TIME_TEMPLATE_KEY = "retodo.timeTemplate";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

export const getOrCreateDeviceId = (): string => {
  if (sessionDeviceId) return sessionDeviceId;
  sessionDeviceId = createId();
  return sessionDeviceId;
};

export const loadTimeTemplate = (): TimeTemplate => {
  if (typeof window === "undefined") return DEFAULT_TIME_TEMPLATE;

  const raw = window.localStorage.getItem(TIME_TEMPLATE_KEY);
  if (!raw) return DEFAULT_TIME_TEMPLATE;

  try {
    const parsed = JSON.parse(raw) as TimeTemplate;
    if (!parsed || !Array.isArray(parsed.weeklyRanges)) return DEFAULT_TIME_TEMPLATE;
    return {
      timezone: parsed.timezone || DEFAULT_TIME_TEMPLATE.timezone,
      weeklyRanges: parsed.weeklyRanges
    };
  } catch {
    return DEFAULT_TIME_TEMPLATE;
  }
};

export const saveTimeTemplate = (template: TimeTemplate): void => {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(TIME_TEMPLATE_KEY, JSON.stringify(template));
};

export const downloadMarkdown = (tasks: Task[]): void => {
  const lines = tasks.map((task) => {
    const status = task.status === "done" ? "x" : " ";
    const tags = task.tags.map((tag) => `#${tag}`).join(" ");
    const due = task.dueAt ? ` due:${task.dueAt.slice(0, 10)}` : "";
    const reward = ` reward:${task.scheduleValue.rewardOnTime}`;
    const penalty = ` penalty:${task.scheduleValue.penaltyMissed}`;
    return `- [${status}] ${task.title} ${tags}${due}${reward}${penalty}`.trim();
  });

  const blob = new Blob([lines.join("\n")], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `task-pool-${new Date().toISOString().slice(0, 10)}.md`;
  anchor.click();
  URL.revokeObjectURL(url);
};

export const parseMarkdownImport = (markdown: string): string[] =>
  markdown
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- ["))
    .map((line) => line.replace(/^-\s*\[[x ]\]\s*/i, "").trim())
    .filter(Boolean);
