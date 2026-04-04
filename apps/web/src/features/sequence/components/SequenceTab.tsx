import { type Task } from "@retodo/core";
import { useEffect, useMemo, useRef, useState } from "react";
import TaskBundleBadge from "./TaskBundleBadge";

interface SequenceTabProps {
  focusedTask: Task | null;
  primarySequenceTasks: Task[];
  nextTasks: Task[];
  getCurrentStepForTask: (task: Task) => Task["steps"][number] | null;
  onTaskTap: (task: Task) => void;
  onTaskComplete: (task: Task) => void;
  onTaskEdit: (task: Task) => void;
  onTaskArchive: (task: Task) => void;
  onTaskDelete: (task: Task) => void;
  onReorderPrimarySequence: (orderedTaskIds: string[]) => void;
}

const PRIMARY_SEQUENCE_LIMIT = 7;
const NEXT_TASK_SUMMARY_LIMIT = 5;

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

const reconcileOrderedIds = (orderedIds: string[], nextTaskIds: string[]): string[] => {
  const nextTaskIdSet = new Set(nextTaskIds);
  const retained = orderedIds.filter((taskId) => nextTaskIdSet.has(taskId));
  const retainedSet = new Set(retained);
  const additions = nextTaskIds.filter((taskId) => !retainedSet.has(taskId));
  return [...retained, ...additions];
};

export default function SequenceTab({
  focusedTask,
  primarySequenceTasks,
  nextTasks,
  getCurrentStepForTask,
  onTaskTap,
  onTaskComplete,
  onTaskEdit,
  onTaskArchive,
  onTaskDelete,
  onReorderPrimarySequence
}: SequenceTabProps) {
  const primaryMembershipSignature = useMemo(
    () => [...primarySequenceTasks].map((task) => task.id).sort().join("|"),
    [primarySequenceTasks]
  );
  const [orderedPrimaryIds, setOrderedPrimaryIds] = useState<string[]>(() => primarySequenceTasks.map((task) => task.id));
  const [draggingTaskId, setDraggingTaskId] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const previousMembershipSignatureRef = useRef(primaryMembershipSignature);

  useEffect(() => {
    const membershipChanged = previousMembershipSignatureRef.current !== primaryMembershipSignature;
    previousMembershipSignatureRef.current = primaryMembershipSignature;

    const nextTaskIds = primarySequenceTasks.map((task) => task.id);
    setOrderedPrimaryIds((current) => {
      if (!isEditing) {
        return nextTaskIds;
      }

      return reconcileOrderedIds(current, nextTaskIds);
    });
    setDraggingTaskId(null);
    if (membershipChanged) {
      setIsEditing(false);
    }
  }, [isEditing, primaryMembershipSignature, primarySequenceTasks]);

  const orderedPrimaryTasks = useMemo(() => {
    const byId = new Map(primarySequenceTasks.map((task) => [task.id, task]));
    const ordered = orderedPrimaryIds.map((taskId) => byId.get(taskId)).filter((task): task is Task => Boolean(task));
    const seen = new Set(ordered.map((task) => task.id));
    const missing = primarySequenceTasks.filter((task) => !seen.has(task.id));
    return [...ordered, ...missing];
  }, [orderedPrimaryIds, primarySequenceTasks]);

  const displayedPrimaryTasks = useMemo(
    () => orderedPrimaryTasks.slice(0, PRIMARY_SEQUENCE_LIMIT),
    [orderedPrimaryTasks]
  );
  const overflowPrimaryTasks = useMemo(
    () => orderedPrimaryTasks.slice(PRIMARY_SEQUENCE_LIMIT),
    [orderedPrimaryTasks]
  );
  const combinedNextTasks = useMemo(
    () => [...overflowPrimaryTasks, ...nextTasks],
    [nextTasks, overflowPrimaryTasks]
  );
  const summarizedNextTasks = useMemo(
    () => combinedNextTasks.slice(0, NEXT_TASK_SUMMARY_LIMIT),
    [combinedNextTasks]
  );

  const commitPrimaryOrder = () => {
    const currentOrder = primarySequenceTasks.map((task) => task.id);
    if (currentOrder.join("|") === orderedPrimaryIds.join("|")) return;
    onReorderPrimarySequence(orderedPrimaryIds);
  };

  const finishEditing = () => {
    commitPrimaryOrder();
    setDraggingTaskId(null);
    setIsEditing(false);
  };

  return (
    <div className="sequence-screen">
      <section className="sequence-section">
        <div className="sequence-section-heading">
          <div className="sequence-section-title">当前聚焦</div>
        </div>

        {focusedTask ? (
          <button className="focus-card" onClick={() => (isEditing ? finishEditing() : onTaskTap(focusedTask))}>
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

            <TaskBundleBadge task={focusedTask} />

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
            <div className="focus-card-title">暂无进行中任务</div>
          </div>
        )}
      </section>

      <section className="sequence-section">
        <div className="sequence-section-head">
          <div className="sequence-section-heading">
            <div className="sequence-section-title">当前序列</div>
          </div>

          <button className={`sequence-section-action${isEditing ? " editing" : ""}`} onClick={() => (isEditing ? finishEditing() : setIsEditing(true))}>
            {isEditing ? "完成编辑" : "编辑"}
          </button>
        </div>

        {displayedPrimaryTasks.length === 0 ? (
          <div className="sequence-empty-card">当前序列为空</div>
        ) : (
          <div className="primary-sequence-list">
            {displayedPrimaryTasks.map((task, index) => {
              const currentStep = getCurrentStepForTask(task);
              const cardContent = (
                <>
                  <div className="sequence-card-header">
                    <div className="sequence-card-title-group">
                      {isEditing && <span className="drag-indicator">⋮⋮</span>}
                      <div className="sequence-card-title">{task.title}</div>
                    </div>
                    <span className={`status-pill status-${task.status}`}>{statusLabel(task.status)}</span>
                  </div>

                  <div className="sequence-card-meta">
                    <span>估时 {task.estimatedMinutes} 分钟</span>
                    {dueLabel(task.dueAt) && <span>{dueLabel(task.dueAt)}</span>}
                    {task.tags.slice(0, 2).map((tag) => (
                      <span key={tag}>#{tag}</span>
                    ))}
                  </div>

                  <TaskBundleBadge task={task} />

                  {currentStep && (
                    <div className="step-preview compact">
                      <div className="step-preview-label">当前步骤</div>
                      <div className="step-preview-title">{currentStep.title}</div>
                      <div className="step-preview-meta">
                        {task.steps.findIndex((step) => step.id === currentStep.id) + 1}/{task.steps.length}
                      </div>
                    </div>
                  )}

                  {isEditing && (
                    <div className="sequence-card-actions">
                      <button type="button" className="sequence-card-action" onClick={() => {
                        onTaskComplete(task);
                        finishEditing();
                      }}>
                        完成
                      </button>
                      <button type="button" className="sequence-card-action" onClick={() => {
                        onTaskEdit(task);
                        setDraggingTaskId(null);
                        setIsEditing(false);
                      }}>
                        编辑
                      </button>
                      <button type="button" className="sequence-card-action" onClick={() => {
                        onTaskArchive(task);
                        finishEditing();
                      }}>
                        归档
                      </button>
                      <button type="button" className="sequence-card-action danger" onClick={() => {
                        if (window.confirm("删除这个任务？该操作不可恢复。")) {
                          onTaskDelete(task);
                          finishEditing();
                        }
                      }}>
                        删除
                      </button>
                    </div>
                  )}
                </>
              );

              return (
                <article
                  key={task.id}
                  className={`timeline-row${draggingTaskId === task.id ? " dragging" : ""}`}
                  draggable={isEditing}
                  onDragStart={(event) => {
                    if (!isEditing) return;
                    event.dataTransfer.effectAllowed = "move";
                    event.dataTransfer.setData("text/plain", task.id);
                    setDraggingTaskId(task.id);
                  }}
                  onDragOver={(event) => {
                    if (!isEditing) return;
                    event.preventDefault();
                    if (!draggingTaskId || draggingTaskId === task.id) return;
                    setOrderedPrimaryIds((current) => moveTaskId(current, draggingTaskId, task.id));
                  }}
                  onDragEnd={() => {
                    if (!isEditing) return;
                    commitPrimaryOrder();
                    setDraggingTaskId(null);
                  }}
                >
                  <div className={`timeline-marker marker-${index === 0 ? "first" : index === displayedPrimaryTasks.length - 1 ? "last" : "middle"}`}>
                    <span className={`timeline-node status-${task.status}`} />
                  </div>

                  {isEditing ? (
                    <div className="sequence-card primary editing">
                      {cardContent}
                    </div>
                  ) : (
                    <button className="sequence-card primary" onClick={() => onTaskTap(task)}>
                      {cardContent}
                    </button>
                  )}
                </article>
              );
            })}
          </div>
        )}
      </section>

      <section className="sequence-section">
        <div className="sequence-section-heading">
          <div className="sequence-section-title">接下来</div>
        </div>

        {combinedNextTasks.length === 0 ? (
          <div className="sequence-empty-card muted">暂无任务</div>
        ) : (
          <div className="next-tasks-summary">
            {summarizedNextTasks.map((task) => (
              <button key={task.id} className="next-task-row" onClick={() => onTaskTap(task)}>
                <span className={`next-task-dot status-${task.status}`} />
                <span className="next-task-copy">
                  <span className="next-task-title">{task.title}</span>
                  <span className="next-task-meta">
                    {[dueLabel(task.dueAt), `${task.estimatedMinutes} 分钟`, task.tags.slice(0, 2).map((tag) => `#${tag}`).join(" ") || null]
                      .filter(Boolean)
                      .join(" · ")}
                  </span>
                </span>
              </button>
            ))}

            {combinedNextTasks.length > NEXT_TASK_SUMMARY_LIMIT && (
              <div className="summary-meta">+{combinedNextTasks.length - NEXT_TASK_SUMMARY_LIMIT}</div>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
