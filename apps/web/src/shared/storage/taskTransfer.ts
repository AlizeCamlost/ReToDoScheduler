import type { Task } from "@retodo/core";

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
