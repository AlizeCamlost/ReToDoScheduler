import type { Task } from "@retodo/core";

const TASK_STORAGE_KEY = "retodo.web.tasks.v1";
const DEVICE_ID_KEY = "retodo.web.device.id";
const API_BASE_URL_KEY = "retodo.web.api.base.url";

export const loadTasks = (): Task[] => {
  const raw = localStorage.getItem(TASK_STORAGE_KEY);
  if (!raw) return [];

  try {
    const parsed = JSON.parse(raw) as Task[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

export const saveTasks = (tasks: Task[]): void => {
  localStorage.setItem(TASK_STORAGE_KEY, JSON.stringify(tasks));
};

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

export const getOrCreateDeviceId = (): string => {
  const existing = localStorage.getItem(DEVICE_ID_KEY);
  if (existing) return existing;
  const next = createId();
  localStorage.setItem(DEVICE_ID_KEY, next);
  return next;
};

export const loadApiBaseUrl = (): string =>
  localStorage.getItem(API_BASE_URL_KEY) ?? "http://127.0.0.1:8787";

export const saveApiBaseUrl = (url: string): void => {
  localStorage.setItem(API_BASE_URL_KEY, url);
};

export const downloadMarkdown = (tasks: Task[]): void => {
  const lines = tasks.map((task) => {
    const status = task.status === "done" ? "x" : " ";
    const tags = task.tags.map((tag) => `#${tag}`).join(" ");
    const due = task.dueAt ? ` due:${task.dueAt.slice(0, 10)}` : "";
    return `- [${status}] ${task.title} ${tags}${due}`.trim();
  });
  const blob = new Blob([lines.join("\n")], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `retodo-export-${new Date().toISOString().slice(0, 10)}.md`;
  anchor.click();
  URL.revokeObjectURL(url);
};

export const parseMarkdownImport = (markdown: string): string[] => {
  return markdown
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- ["))
    .map((line) => line.replace(/^-\s*\[[x ]\]\s*/i, "").trim())
    .filter(Boolean);
};
