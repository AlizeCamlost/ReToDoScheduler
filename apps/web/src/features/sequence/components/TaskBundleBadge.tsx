import { getTaskBundleMetadata, type Task } from "@retodo/core";

interface TaskBundleBadgeProps {
  task: Task;
}

export default function TaskBundleBadge({ task }: TaskBundleBadgeProps) {
  const metadata = getTaskBundleMetadata(task);
  if (!metadata) return null;

  const label =
    metadata.count > 1
      ? `${metadata.title ?? "任务序列"} ${metadata.position + 1}/${metadata.count}`
      : metadata.title ?? "任务序列";

  return (
    <span className="task-bundle-badge">
      <span className="task-bundle-icon">▣</span>
      <span>{label}</span>
    </span>
  );
}
