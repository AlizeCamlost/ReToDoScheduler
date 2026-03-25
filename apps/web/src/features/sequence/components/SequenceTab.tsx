import { type Task } from "@retodo/core";
import { useEffect, useMemo, useState } from "react";

interface SequenceTabProps {
  focusedTask: Task | null;
  primarySequenceTasks: Task[];
  nextTasks: Task[];
  getCurrentStepForTask: (task: Task) => Task["steps"][number] | null;
  onTaskTap: (task: Task) => void;
  onReorderPrimarySequence: (orderedTaskIds: string[]) => void;
}

const statusLabel = (status: Task["status"]): string => {
  switch (status) {
    case "todo":
      return "待开始";
    case "doing":
      return "进行中";
    case "done":
      return "已完成";
    case "archived":
      return "已归档";
  }
};

const dueLabel = (dueAt?: string): string | null => {
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

const moveTaskId = (orderedIds: string[], draggedId: string, destinationId: string): string[] => {
  const next = [...orderedIds];
  const fromIndex = next.indexOf(draggedId);
  const toIndex = next.indexOf(destinationId);
  if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return orderedIds;

  next.splice(fromIndex, 1);
  next.splice(toIndex, 0, draggedId);
  return next;
};

export default function SequenceTab({
  focusedTask,
  primarySequenceTasks,
  nextTasks,
  getCurrentStepForTask,
  onTaskTap,
  onReorderPrimarySequence
}: SequenceTabProps) {
  const primarySignature = useMemo(() => primarySequenceTasks.map((task) => task.id).join("|"), [primarySequenceTasks]);
  const [orderedPrimaryIds, setOrderedPrimaryIds] = useState<string[]>(() => primarySequenceTasks.map((task) => task.id));
  const [draggingTaskId, setDraggingTaskId] = useState<string | null>(null);

  useEffect(() => {
    setOrderedPrimaryIds(primarySequenceTasks.map((task) => task.id));
    setDraggingTaskId(null);
  }, [primarySignature, primarySequenceTasks]);

  const orderedPrimaryTasks = useMemo(() => {
    const byId = new Map(primarySequenceTasks.map((task) => [task.id, task]));
    const ordered = orderedPrimaryIds.map((taskId) => byId.get(taskId)).filter((task): task is Task => Boolean(task));
    const seen = new Set(ordered.map((task) => task.id));
    const missing = primarySequenceTasks.filter((task) => !seen.has(task.id));
    return [...ordered, ...missing];
  }, [orderedPrimaryIds, primarySequenceTasks]);

  const commitPrimaryOrder = () => {
    const currentOrder = primarySequenceTasks.map((task) => task.id);
    if (currentOrder.join("|") === orderedPrimaryIds.join("|")) return;
    onReorderPrimarySequence(orderedPrimaryIds);
  };

  return (
    <div className="sequence-screen">
      <section className="sequence-section">
        <div className="sequence-section-heading">
          <div className="sequence-section-title">当前聚焦</div>
          <div className="sequence-section-detail">如果已经有进行中的任务，就先把它留在视野顶部。</div>
        </div>

        {focusedTask ? (
          <button className="focus-card" onClick={() => onTaskTap(focusedTask)}>
            <div className="focus-card-header">
              <div>
                <div className="focus-card-eyebrow">当前聚焦</div>
                <div className="focus-card-title">{focusedTask.title}</div>
              </div>
              <span className={`status-pill status-${focusedTask.status}`}>{statusLabel(focusedTask.status)}</span>
            </div>

            {focusedTask.description && <p className="focus-card-description">{focusedTask.description}</p>}

            <div className="chip-row">
              <span className="soft-chip">估时 {focusedTask.estimatedMinutes} 分钟</span>
              <span className="soft-chip">最小块 {focusedTask.minChunkMinutes} 分钟</span>
              {dueLabel(focusedTask.dueAt) && <span className="soft-chip">{dueLabel(focusedTask.dueAt)}</span>}
            </div>

            {getCurrentStepForTask(focusedTask) && (
              <div className="step-preview regular">
                <div className="step-preview-label">当前步骤</div>
                <div className="step-preview-title">{getCurrentStepForTask(focusedTask)?.title}</div>
                <div className="step-preview-meta">
                  {focusedTask.steps.findIndex((step) => step.id === getCurrentStepForTask(focusedTask)?.id) + 1}/{focusedTask.steps.length}
                </div>
              </div>
            )}
          </button>
        ) : (
          <div className="focus-card empty">
            <div className="focus-card-eyebrow">当前聚焦</div>
            <div className="focus-card-title">还没有进行中的任务</div>
            <p className="focus-card-description">把真正要先做的任务切到“进行中”，这里就会固定呈现它。</p>
          </div>
        )}
      </section>

      <section className="sequence-section">
        <div className="sequence-section-heading">
          <div className="sequence-section-title">主序列</div>
          <div className="sequence-section-detail">按拖拽顺序表达你想优先推进的执行队列。</div>
        </div>

        {orderedPrimaryTasks.length === 0 ? (
          <div className="sequence-empty-card">没有进入主序列的任务。Quick Add 新建后会先落到这里。</div>
        ) : (
          <div className="primary-sequence-list">
            {orderedPrimaryTasks.map((task, index) => {
              const currentStep = getCurrentStepForTask(task);
              return (
                <article
                  key={task.id}
                  className={`timeline-row${draggingTaskId === task.id ? " dragging" : ""}`}
                  draggable
                  onDragStart={(event) => {
                    event.dataTransfer.effectAllowed = "move";
                    event.dataTransfer.setData("text/plain", task.id);
                    setDraggingTaskId(task.id);
                  }}
                  onDragOver={(event) => {
                    event.preventDefault();
                    if (!draggingTaskId || draggingTaskId === task.id) return;
                    setOrderedPrimaryIds((current) => moveTaskId(current, draggingTaskId, task.id));
                  }}
                  onDragEnd={() => {
                    commitPrimaryOrder();
                    setDraggingTaskId(null);
                  }}
                >
                  <div className={`timeline-marker marker-${index === 0 ? "first" : index === orderedPrimaryTasks.length - 1 ? "last" : "middle"}`}>
                    <span className={`timeline-node status-${task.status}`} />
                  </div>

                  <button className="sequence-card primary" onClick={() => onTaskTap(task)}>
                    <div className="sequence-card-header">
                      <span className="drag-indicator">⋮⋮</span>
                      <div className="sequence-card-title">{task.title}</div>
                      <span className={`status-pill status-${task.status}`}>{statusLabel(task.status)}</span>
                    </div>

                    <div className="sequence-card-meta">
                      <span>估时 {task.estimatedMinutes} 分钟</span>
                      {dueLabel(task.dueAt) && <span>{dueLabel(task.dueAt)}</span>}
                      {task.tags.slice(0, 2).map((tag) => (
                        <span key={tag}>#{tag}</span>
                      ))}
                    </div>

                    {currentStep && (
                      <div className="step-preview compact">
                        <div className="step-preview-label">当前步骤</div>
                        <div className="step-preview-title">{currentStep.title}</div>
                        <div className="step-preview-meta">
                          {task.steps.findIndex((step) => step.id === currentStep.id) + 1}/{task.steps.length}
                        </div>
                      </div>
                    )}
                  </button>
                </article>
              );
            })}
          </div>
        )}
      </section>

      <section className="sequence-section">
        <div className="sequence-section-heading">
          <div className="sequence-section-title">接下来</div>
          <div className="sequence-section-detail">不急着塞进主序列的任务先留在这里，避免把当前视野挤爆。</div>
        </div>

        {nextTasks.length === 0 ? (
          <div className="sequence-empty-card muted">接下来区域暂时为空，说明当前任务大多都已被纳入主序列。</div>
        ) : (
          <div className="next-sequence-grid">
            {nextTasks.map((task) => (
              <button key={task.id} className="sequence-card next" onClick={() => onTaskTap(task)}>
                <div className="sequence-card-header">
                  <div className="sequence-card-title">{task.title}</div>
                  {dueLabel(task.dueAt) && <span className="soft-badge">{dueLabel(task.dueAt)}</span>}
                </div>

                <div className="sequence-card-meta">
                  <span>{task.estimatedMinutes} 分钟</span>
                  <span>{task.tags.slice(0, 2).map((tag) => `#${tag}`).join(" ") || "尚未添加标签"}</span>
                </div>
              </button>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
