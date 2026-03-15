import { describeTaskMeta, type Task } from "@retodo/core";

interface TaskItemProps {
  task: Task;
  onToggleDone: () => void;
  onArchive: () => void;
  onEdit: () => void;
}

const getDueLabel = (dueAt?: string): string | null => {
  if (!dueAt) return null;

  const now = new Date();
  const due = new Date(dueAt);
  now.setHours(0, 0, 0, 0);
  due.setHours(0, 0, 0, 0);

  const diffDays = Math.round((due.getTime() - now.getTime()) / 86_400_000);
  if (diffDays < 0) return `逾期 ${Math.abs(diffDays)} 天`;
  if (diffDays === 0) return "今天截止";
  if (diffDays === 1) return "明天截止";
  return `${diffDays} 天后截止`;
};

export default function TaskItem({ task, onToggleDone, onArchive, onEdit }: TaskItemProps) {
  const isDone = task.status === "done";
  const dueLabel = getDueLabel(task.dueAt);

  return (
    <li className={`task-item${isDone ? " done-item" : ""}`}>
      <button
        className={`task-checkbox${isDone ? " checked" : ""}`}
        onClick={onToggleDone}
        title={isDone ? "标记未完成" : "标记完成"}
      />

      <div className="task-body" onClick={onEdit}>
        <div className={`task-title${isDone ? " done" : ""}`}>{task.title}</div>

        <div className="task-meta">
          <span>{describeTaskMeta(task)}</span>
          {dueLabel && <span className="task-meta-sep">{dueLabel}</span>}
        </div>

        {(task.dependsOnTaskIds.length > 0 || task.steps.length > 0 || task.tags.length > 0) && (
          <div className="task-tags">
            {task.dependsOnTaskIds.length > 0 && <span className="badge subtle">依赖 {task.dependsOnTaskIds.length}</span>}
            {task.steps.length > 0 && <span className="badge subtle">步骤 {task.steps.length}</span>}
            {task.tags.map((tag) => (
              <span key={tag} className="badge">
                #{tag}
              </span>
            ))}
          </div>
        )}
      </div>

      <div className="task-actions visible">
        <button className="btn-action" onClick={onEdit}>
          编辑
        </button>
        <button className="btn-action danger" onClick={onArchive}>
          删除
        </button>
      </div>
    </li>
  );
}
