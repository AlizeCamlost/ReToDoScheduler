import type { Task } from "@retodo/core";
import TaskItem from "./TaskItem";

interface TaskPoolPanelProps {
  tasks: Task[];
  searchQuery: string;
  onSearchQueryChange: (value: string) => void;
  onToggleDone: (taskId: string) => void;
  onArchive: (taskId: string) => void;
  onOpenDetail: (task: Task) => void;
  onEdit: (task: Task) => void;
}

export default function TaskPoolPanel({
  tasks,
  searchQuery,
  onSearchQueryChange,
  onToggleDone,
  onArchive,
  onOpenDetail,
  onEdit
}: TaskPoolPanelProps) {
  return (
    <section className="card">
      <div className="panel-header">
        <div>
          <div className="panel-title">任务池</div>
          <div className="panel-caption">任务、依赖、子步骤都在这里维护。</div>
        </div>
        <div className="search-wrapper compact">
          <span className="search-icon">🔍</span>
          <input
            className="search-input"
            value={searchQuery}
            onChange={(event) => onSearchQueryChange(event.target.value)}
            placeholder="搜索任务"
          />
        </div>
      </div>

      <ul className="task-list">
        {tasks.length === 0 && <li className="empty-state">没有匹配的任务</li>}
        {tasks.map((task) => (
          <TaskItem
            key={task.id}
            task={task}
            onToggleDone={() => onToggleDone(task.id)}
            onArchive={() => onArchive(task.id)}
            onOpenDetail={() => onOpenDetail(task)}
            onEdit={() => onEdit(task)}
          />
        ))}
      </ul>
    </section>
  );
}
