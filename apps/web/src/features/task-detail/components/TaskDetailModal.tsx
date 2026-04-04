import { getTaskStepProgressState, type Task } from "@retodo/core";
import { type FormEvent, useEffect, useMemo, useRef, useState } from "react";

interface TaskDetailModalProps {
  task: Task;
  currentStep: Task["steps"][number] | null;
  onClose: () => void;
  onEdit: () => void;
  onToggleCompletion: () => void;
  onArchive: () => void;
  onPromoteToDoing: () => void;
  onAddStep: (title: string) => void;
  onCompleteCurrentStep: (stepId: string) => void;
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

const dueLabel = (dueAt?: string): string => {
  if (!dueAt) return "未设置";
  return new Date(dueAt).toLocaleDateString("zh-CN", { month: "long", day: "numeric", weekday: "short" });
};

export default function TaskDetailModal({
  task,
  currentStep,
  onClose,
  onEdit,
  onToggleCompletion,
  onArchive,
  onPromoteToDoing,
  onAddStep,
  onCompleteCurrentStep
}: TaskDetailModalProps) {
  const [newStepTitle, setNewStepTitle] = useState("");
  const overlayRef = useRef<HTMLDivElement>(null);
  const currentStepIndex = useMemo(
    () => (currentStep ? task.steps.findIndex((step) => step.id === currentStep.id) : -1),
    [currentStep, task.steps]
  );

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const handleOverlayClick = (event: React.MouseEvent) => {
    if (event.target === overlayRef.current) onClose();
  };

  const handleAddStep = (event: FormEvent) => {
    event.preventDefault();
    if (!newStepTitle.trim()) return;
    onAddStep(newStepTitle.trim());
    setNewStepTitle("");
  };

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal detail-modal" role="dialog" aria-label="任务详情">
        <div className="modal-header">
          <h2>任务详情</h2>
          <div className="detail-header-actions">
            <button className="btn-text" onClick={onEdit}>
              编辑
            </button>
            <button className="btn-close" onClick={onClose} title="关闭">
              ×
            </button>
          </div>
        </div>

        <div className="modal-body detail-modal-body">
          <section className="detail-hero">
            <div className="detail-hero-copy">
              <div className="detail-eyebrow">任务</div>
              <h3>{task.title}</h3>
              {task.description && <p>{task.description}</p>}
            </div>

            <div className="chip-row">
              <span className={`status-pill status-${task.status}`}>{statusLabel(task.status)}</span>
              <span className="soft-chip">估时 {task.estimatedMinutes} 分钟</span>
              <span className="soft-chip">最小块 {task.minChunkMinutes} 分钟</span>
            </div>
          </section>

          <section className="detail-panel">
            <div className="detail-panel-title">快捷操作</div>
            <div className="detail-action-list">
              <button className="detail-action-row" onClick={onPromoteToDoing}>
                <span>{task.status === "doing" ? "已在进行中" : "切到进行中"}</span>
              </button>

              <form className="detail-inline-form" onSubmit={handleAddStep}>
                <input
                  className="detail-inline-input"
                  value={newStepTitle}
                  onChange={(event) => setNewStepTitle(event.target.value)}
                  placeholder="追加一个新的串行步骤"
                />
                <button className="btn-primary" type="submit">
                  添加步骤
                </button>
              </form>

              {currentStep && (
                <button className="detail-action-row accent" onClick={() => onCompleteCurrentStep(currentStep.id)}>
                  <span>推进当前步骤</span>
                  <span>{currentStep.title}</span>
                </button>
              )}
            </div>
          </section>

          <section className="detail-panel meta">
            <div className="detail-panel-title">元信息</div>
            <div className="detail-meta-grid">
              <div className="detail-meta-item">
                <span className="detail-meta-label">截止</span>
                <span className="detail-meta-value">{dueLabel(task.dueAt)}</span>
              </div>
              <div className="detail-meta-item">
                <span className="detail-meta-label">价值</span>
                <span className="detail-meta-value">
                  按时 +{task.scheduleValue.rewardOnTime} / 逾期 -{task.scheduleValue.penaltyMissed}
                </span>
              </div>
              <div className="detail-meta-item">
                <span className="detail-meta-label">依赖</span>
                <span className="detail-meta-value">
                  {task.dependsOnTaskIds.length > 0 ? task.dependsOnTaskIds.join("、") : "无"}
                </span>
              </div>
              <div className="detail-meta-item">
                <span className="detail-meta-label">步骤</span>
                <span className="detail-meta-value">
                  {task.steps.length > 0
                    ? `${task.steps.length} 步${currentStep ? `，当前 ${currentStepIndex + 1}/${task.steps.length}` : ""}`
                    : "无"}
                </span>
              </div>
            </div>
          </section>

          {task.steps.length > 0 && (
            <section className="detail-panel">
              <div className="detail-panel-title">子步骤串</div>
              <div className="detail-step-list">
                {task.steps.map((step, index) => {
                  const state = getTaskStepProgressState(task, step.id);
                  const isCurrent = state === "current";
                  return (
                    <button
                      key={step.id}
                      className={`detail-step-row state-${state ?? "upcoming"}`}
                      onClick={() => {
                        if (isCurrent) onCompleteCurrentStep(step.id);
                      }}
                      disabled={!isCurrent}
                    >
                      <span className="detail-step-index">{index + 1}</span>
                      <span className="detail-step-content">
                        <span className="detail-step-title">{step.title}</span>
                        <span className="detail-step-meta">
                          {step.estimatedMinutes} 分钟 · 最小块 {step.minChunkMinutes} 分钟
                        </span>
                      </span>
                      <span className="detail-step-state">
                        {state === "completed" ? "已完成" : state === "current" ? "点击推进" : "待开始"}
                      </span>
                    </button>
                  );
                })}
              </div>
            </section>
          )}

          {task.tags.length > 0 && (
            <section className="detail-panel">
              <div className="detail-panel-title">标签</div>
              <div className="chip-row">
                {task.tags.map((tag) => (
                  <span key={tag} className="soft-badge">
                    #{tag}
                  </span>
                ))}
              </div>
            </section>
          )}

          <section className="detail-panel">
            <div className="detail-panel-title">原始输入</div>
            <pre className="detail-raw-input">{task.rawInput || "暂无原始输入"}</pre>
          </section>

          <section className="detail-panel">
            <div className="detail-panel-title">操作</div>
            <div className="detail-footer-actions">
              <button className="btn-secondary" onClick={onToggleCompletion}>
                {task.status === "done" ? "恢复待办" : "标记完成"}
              </button>
              <button
                className="btn-secondary danger-secondary"
                onClick={() => {
                  if (window.confirm("归档这个任务？归档后会从当前视图隐藏。")) {
                    onArchive();
                  }
                }}
              >
                归档任务
              </button>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
