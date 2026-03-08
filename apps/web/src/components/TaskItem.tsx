import type { Task } from "@retodo/core";

interface TaskItemProps {
  task: Task;
  isDragging: boolean;
  onToggleDone: () => void;
  onArchive: () => void;
  onEdit: () => void;
  onDragStart: () => void;
  onDragOver: (e: React.DragEvent) => void;
  onDrop: () => void;
}

function getDueLabel(dueAt: string): { text: string; className: string } {
  const now = new Date();
  const due = new Date(dueAt);
  now.setHours(0, 0, 0, 0);
  due.setHours(0, 0, 0, 0);
  const diffMs = due.getTime() - now.getTime();
  const diffDays = Math.round(diffMs / 86_400_000);

  if (diffDays < 0) return { text: `逾期 ${Math.abs(diffDays)} 天`, className: "due-overdue" };
  if (diffDays === 0) return { text: "今天截止", className: "due-today" };
  if (diffDays === 1) return { text: "明天截止", className: "due-today" };
  if (diffDays <= 7) return { text: `${diffDays} 天后截止`, className: "due-upcoming" };
  return { text: dueAt.slice(0, 10), className: "due-upcoming" };
}

export default function TaskItem({
  task,
  isDragging,
  onToggleDone,
  onArchive,
  onEdit,
  onDragStart,
  onDragOver,
  onDrop
}: TaskItemProps) {
  const isDone = task.status === "done";
  const dueInfo = task.dueAt ? getDueLabel(task.dueAt) : null;

  return (
    <li
      className={`task-item${isDragging ? " dragging" : ""}${isDone ? " done-item" : ""}`}
      draggable
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
    >
      <span className="drag-handle" title="拖拽排序">
        ⠿
      </span>

      <button
        className={`task-checkbox${isDone ? " checked" : ""}`}
        onClick={(e) => {
          e.stopPropagation();
          onToggleDone();
        }}
        title={isDone ? "标记未完成" : "标记完成"}
      />

      <div className="task-body" onClick={onEdit}>
        <div className={`task-title${isDone ? " done" : ""}`}>{task.title}</div>

        <div className="task-meta">
          <span>估时 {task.estimatedMinutes}m</span>
          <span className="task-meta-sep">拆分 {task.minChunkMinutes}m</span>
          {dueInfo && (
            <span className={`task-meta-sep ${dueInfo.className}`}>{dueInfo.text}</span>
          )}
        </div>

        {task.tags.length > 0 && (
          <div className="task-tags">
            {task.tags.map((tag) => (
              <span key={tag} className="badge">
                #{tag}
              </span>
            ))}
          </div>
        )}
      </div>

      <div className="task-actions">
        <button
          className="btn-action danger"
          onClick={(e) => {
            e.stopPropagation();
            onArchive();
          }}
          title="删除"
        >
          删除
        </button>
      </div>
    </li>
  );
}
