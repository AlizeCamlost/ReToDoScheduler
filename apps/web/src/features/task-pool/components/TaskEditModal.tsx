import {
  makeTask,
  nowIso,
  type Task,
  type TaskStepProgress,
  type TaskStepTemplate
} from "@retodo/core";
import { type FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";

interface TaskEditModalProps {
  task: Task;
  allTasks: Task[];
  onSave: (updated: Task) => void;
  onClose: () => void;
}

interface EditableStep extends TaskStepTemplate {}

const isTaskStepProgress = (value: unknown): value is TaskStepProgress =>
  !!value && typeof value === "object" && !Array.isArray(value);

const slugify = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fa5-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 32);

const normalizeSteps = (steps: EditableStep[]): TaskStepTemplate[] =>
  steps
    .map((step, index) => {
      const title = step.title.trim() || `步骤 ${index + 1}`;
      const id = step.id.trim() || slugify(title) || `step-${index + 1}`;
      return {
        id,
        title,
        estimatedMinutes: Math.max(1, Number(step.estimatedMinutes) || 30),
        minChunkMinutes: Math.max(1, Number(step.minChunkMinutes) || 25),
        dependsOnStepIds: step.dependsOnStepIds.filter(Boolean),
        progress: isTaskStepProgress(step.progress) ? { ...step.progress } : undefined
      };
    })
    .filter((step) => step.title.trim().length > 0);

export default function TaskEditModal({ task, allTasks, onSave, onClose }: TaskEditModalProps) {
  const [title, setTitle] = useState(task.title);
  const [description, setDescription] = useState(task.description ?? "");
  const [estimatedMinutes, setEstimatedMinutes] = useState(String(task.estimatedMinutes));
  const [minChunkMinutes, setMinChunkMinutes] = useState(String(task.minChunkMinutes));
  const [dueAt, setDueAt] = useState(task.dueAt?.slice(0, 10) ?? "");
  const [tagsInput, setTagsInput] = useState(task.tags.join(", "));
  const [rewardOnTime, setRewardOnTime] = useState(String(task.scheduleValue.rewardOnTime));
  const [penaltyMissed, setPenaltyMissed] = useState(String(task.scheduleValue.penaltyMissed));
  const [dependsOnTaskIds, setDependsOnTaskIds] = useState<string[]>(task.dependsOnTaskIds);
  const [steps, setSteps] = useState<EditableStep[]>(
    task.steps.length > 0
      ? task.steps.map((step) => ({ ...step }))
      : []
  );

  const titleRef = useRef<HTMLInputElement>(null);
  const overlayRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    titleRef.current?.focus();
  }, []);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const dependencyCandidates = useMemo(
    () => allTasks.filter((candidate) => candidate.id !== task.id && candidate.status !== "archived"),
    [allTasks, task.id]
  );

  const handleOverlayClick = useCallback(
    (event: React.MouseEvent) => {
      if (event.target === overlayRef.current) onClose();
    },
    [onClose]
  );

  const toggleDependency = (taskId: string) => {
    setDependsOnTaskIds((current) =>
      current.includes(taskId) ? current.filter((id) => id !== taskId) : [...current, taskId]
    );
  };

  const updateStep = (index: number, patch: Partial<EditableStep>) => {
    setSteps((current) =>
      current.map((step, currentIndex) => (currentIndex === index ? { ...step, ...patch } : step))
    );
  };

  const removeStep = (index: number) => {
    setSteps((current) => current.filter((_, currentIndex) => currentIndex !== index));
  };

  const addStep = () => {
    setSteps((current) => [
      ...current,
      {
        id: `step-${current.length + 1}`,
        title: "",
        estimatedMinutes: 30,
        minChunkMinutes: 25,
        dependsOnStepIds: current.length > 0 ? [current[current.length - 1]?.id ?? ""] : [],
        progress: undefined
      }
    ]);
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    if (!title.trim()) return;

    const normalizedSteps = normalizeSteps(steps);
    const validStepIds = new Set(normalizedSteps.map((step) => step.id));
    const filteredSteps = normalizedSteps.map((step) => ({
      ...step,
      dependsOnStepIds: step.dependsOnStepIds.filter((stepId) => validStepIds.has(stepId) && stepId !== step.id)
    }));

    const updated = makeTask({
      ...task,
      title: title.trim(),
      rawInput: task.rawInput || title.trim(),
      description: description.trim() || undefined,
      estimatedMinutes: Math.max(1, Number(estimatedMinutes) || task.estimatedMinutes),
      minChunkMinutes: Math.max(1, Number(minChunkMinutes) || task.minChunkMinutes),
      dueAt: dueAt ? new Date(`${dueAt}T23:59:59`).toISOString() : undefined,
      tags: tagsInput
        .split(",")
        .map((tag) => tag.trim().replace(/^#/, ""))
        .filter(Boolean),
      scheduleValue: {
        rewardOnTime: Math.max(0, Number(rewardOnTime) || task.scheduleValue.rewardOnTime),
        penaltyMissed: Math.max(0, Number(penaltyMissed) || task.scheduleValue.penaltyMissed)
      },
      dependsOnTaskIds,
      steps: filteredSteps,
      updatedAt: nowIso()
    });

    onSave(updated);
  };

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal modal-wide" role="dialog" aria-label="编辑任务">
        <div className="modal-header">
          <h2>编辑任务</h2>
          <button className="btn-close" onClick={onClose} title="关闭">
            ×
          </button>
        </div>

        <form className="modal-form" onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-section">
              <div className="form-section-title">基本信息</div>
              <div className="form-group">
                <label className="form-label" htmlFor="edit-title">
                  标题
                </label>
                <input
                  ref={titleRef}
                  id="edit-title"
                  className="form-input"
                  value={title}
                  onChange={(event) => setTitle(event.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="edit-description">
                  描述
                </label>
                <textarea
                  id="edit-description"
                  className="form-textarea"
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  rows={3}
                />
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="edit-tags">
                  标签
                </label>
                <input
                  id="edit-tags"
                  className="form-input"
                  value={tagsInput}
                  onChange={(event) => setTagsInput(event.target.value)}
                  placeholder="逗号分隔，例如：工作, ddl"
                />
              </div>
            </div>

            <div className="form-section">
              <div className="form-section-title">约束与价值</div>
              <div className="form-row">
                <div className="form-group">
                  <label className="form-label">总耗时（分钟）</label>
                  <input
                    className="form-input"
                    type="number"
                    min="1"
                    value={estimatedMinutes}
                    onChange={(event) => setEstimatedMinutes(event.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">最小块（分钟）</label>
                  <input
                    className="form-input"
                    type="number"
                    min="1"
                    value={minChunkMinutes}
                    onChange={(event) => setMinChunkMinutes(event.target.value)}
                  />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label className="form-label">截止日期</label>
                  <input className="form-input" type="date" value={dueAt} onChange={(event) => setDueAt(event.target.value)} />
                </div>
                <div className="form-group">
                  <label className="form-label">按时收益</label>
                  <input
                    className="form-input"
                    type="number"
                    min="0"
                    value={rewardOnTime}
                    onChange={(event) => setRewardOnTime(event.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">错过损失</label>
                  <input
                    className="form-input"
                    type="number"
                    min="0"
                    value={penaltyMissed}
                    onChange={(event) => setPenaltyMissed(event.target.value)}
                  />
                </div>
              </div>
            </div>

            <div className="form-section">
              <div className="form-section-title">任务依赖</div>
              {dependencyCandidates.length === 0 ? (
                <div className="empty-panel">暂无可依赖任务</div>
              ) : (
                <div className="dependency-grid">
                  {dependencyCandidates.map((candidate) => (
                    <label key={candidate.id} className="dependency-option">
                      <input
                        type="checkbox"
                        checked={dependsOnTaskIds.includes(candidate.id)}
                        onChange={() => toggleDependency(candidate.id)}
                      />
                      <span>{candidate.title}</span>
                    </label>
                  ))}
                </div>
              )}
            </div>

            <div className="form-section">
              <div className="form-section-header">
                <div className="form-section-title">子步骤</div>
                <button type="button" className="btn-text" onClick={addStep}>
                  添加步骤
                </button>
              </div>
              {steps.map((step, index) => (
                <div key={`${step.id}-${index}`} className="step-card">
                  <div className="form-row">
                    <div className="form-group">
                      <label className="form-label">步骤 ID</label>
                      <input
                        className="form-input"
                        value={step.id}
                        onChange={(event) => updateStep(index, { id: event.target.value })}
                        placeholder={`step-${index + 1}`}
                      />
                    </div>
                    <div className="form-group grow">
                      <label className="form-label">步骤标题</label>
                      <input
                        className="form-input"
                        value={step.title}
                        onChange={(event) => updateStep(index, { title: event.target.value })}
                      />
                    </div>
                  </div>
                  <div className="form-row">
                    <div className="form-group">
                      <label className="form-label">耗时</label>
                      <input
                        className="form-input"
                        type="number"
                        min="1"
                        value={step.estimatedMinutes}
                        onChange={(event) => updateStep(index, { estimatedMinutes: Number(event.target.value) })}
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label">最小块</label>
                      <input
                        className="form-input"
                        type="number"
                        min="1"
                        value={step.minChunkMinutes}
                        onChange={(event) => updateStep(index, { minChunkMinutes: Number(event.target.value) })}
                      />
                    </div>
                    <div className="form-group grow">
                      <label className="form-label">依赖步骤 ID（逗号分隔）</label>
                      <input
                        className="form-input"
                        value={step.dependsOnStepIds.join(", ")}
                        onChange={(event) =>
                          updateStep(index, {
                            dependsOnStepIds: event.target.value
                              .split(",")
                              .map((value) => value.trim())
                              .filter(Boolean)
                          })
                        }
                      />
                    </div>
                  </div>
                  <div className="step-actions">
                    <button type="button" className="btn-action danger" onClick={() => removeStep(index)}>
                      删除步骤
                    </button>
                  </div>
                </div>
              ))}
            </div>

          </div>

          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>
              取消
            </button>
            <button type="submit" className="btn-primary">
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
