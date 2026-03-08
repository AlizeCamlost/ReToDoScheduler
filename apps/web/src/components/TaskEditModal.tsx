import { nowIso, type Task, type FocusLevel, type Interruptibility, type LocationType, type DeviceType } from "@retodo/core";
import { type FormEvent, useState, useRef, useCallback, useEffect } from "react";

interface TaskEditModalProps {
  task: Task;
  onSave: (updated: Task) => void;
  onClose: () => void;
}

export default function TaskEditModal({ task, onSave, onClose }: TaskEditModalProps) {
  const [title, setTitle] = useState(task.title);
  const [description, setDescription] = useState(task.description ?? "");
  const [estimatedMinutes, setEstimatedMinutes] = useState(String(task.estimatedMinutes));
  const [minChunkMinutes, setMinChunkMinutes] = useState(String(task.minChunkMinutes));
  const [dueAt, setDueAt] = useState(task.dueAt?.slice(0, 10) ?? "");
  const [tags, setTags] = useState<string[]>([...task.tags]);
  const [tagInput, setTagInput] = useState("");
  const [importance, setImportance] = useState(String(task.importance));
  const [difficulty, setDifficulty] = useState(String(task.difficulty));
  const [focus, setFocus] = useState<FocusLevel>(task.taskTraits.focus);
  const [interruptibility, setInterruptibility] = useState<Interruptibility>(task.taskTraits.interruptibility);
  const [location, setLocation] = useState<LocationType>(task.taskTraits.location);
  const [device, setDevice] = useState<DeviceType>(task.taskTraits.device);
  const [parallelizable, setParallelizable] = useState(task.taskTraits.parallelizable);

  const overlayRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    titleRef.current?.focus();
  }, []);

  const handleOverlayClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.target === overlayRef.current) onClose();
    },
    [onClose]
  );

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const addTag = () => {
    const raw = tagInput.trim().replace(/^#/, "");
    if (raw && !tags.includes(raw)) {
      setTags([...tags, raw]);
    }
    setTagInput("");
  };

  const removeTag = (tag: string) => {
    setTags(tags.filter((t) => t !== tag));
  };

  const handleTagKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" || e.key === ",") {
      e.preventDefault();
      addTag();
    }
    if (e.key === "Backspace" && tagInput === "" && tags.length > 0) {
      setTags(tags.slice(0, -1));
    }
  };

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const est = Number(estimatedMinutes);
    const chunk = Number(minChunkMinutes);
    const imp = Number(importance);
    const diff = Number(difficulty);

    const updated: Task = {
      ...task,
      title: title.trim(),
      description: description.trim() || undefined,
      estimatedMinutes: Number.isFinite(est) && est > 0 ? est : task.estimatedMinutes,
      minChunkMinutes: Number.isFinite(chunk) && chunk > 0 ? chunk : task.minChunkMinutes,
      dueAt: dueAt ? new Date(dueAt + "T23:59:59").toISOString() : undefined,
      importance: Number.isFinite(imp) ? Math.max(0, Math.min(1, imp)) : task.importance,
      difficulty: Number.isFinite(diff) ? Math.max(0, Math.min(1, diff)) : task.difficulty,
      tags,
      taskTraits: { focus, interruptibility, location, device, parallelizable },
      updatedAt: nowIso()
    };

    onSave(updated);
  };

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal" role="dialog" aria-label="编辑任务">
        <div className="modal-header">
          <h2>编辑任务</h2>
          <button className="btn-close" onClick={onClose} title="关闭">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            {/* 基本信息 */}
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
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="edit-desc">
                  描述
                </label>
                <textarea
                  id="edit-desc"
                  className="form-textarea"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={2}
                  placeholder="可选"
                />
              </div>
            </div>

            {/* 时间 */}
            <div className="form-section">
              <div className="form-section-title">时间</div>
              <div className="form-row">
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-est">
                    预估时长（分钟）
                  </label>
                  <input
                    id="edit-est"
                    className="form-input"
                    type="number"
                    min="1"
                    value={estimatedMinutes}
                    onChange={(e) => setEstimatedMinutes(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-chunk">
                    最小拆分（分钟）
                  </label>
                  <input
                    id="edit-chunk"
                    className="form-input"
                    type="number"
                    min="1"
                    value={minChunkMinutes}
                    onChange={(e) => setMinChunkMinutes(e.target.value)}
                  />
                </div>
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="edit-due">
                  截止日期
                </label>
                <input
                  id="edit-due"
                  className="form-input"
                  type="date"
                  value={dueAt}
                  onChange={(e) => setDueAt(e.target.value)}
                />
              </div>
            </div>

            {/* 标签 */}
            <div className="form-section">
              <div className="form-section-title">标签</div>
              <div className="tag-input-area">
                {tags.map((tag) => (
                  <span key={tag} className="tag-chip">
                    #{tag}
                    <button type="button" onClick={() => removeTag(tag)} title="移除标签">
                      ✕
                    </button>
                  </span>
                ))}
                <input
                  className="tag-input"
                  type="text"
                  value={tagInput}
                  onChange={(e) => setTagInput(e.target.value)}
                  onKeyDown={handleTagKeyDown}
                  onBlur={addTag}
                  placeholder={tags.length === 0 ? "输入标签后回车添加" : ""}
                />
              </div>
            </div>

            {/* 特征 */}
            <div className="form-section">
              <div className="form-section-title">任务特征</div>
              <div className="form-row">
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-focus">
                    专注度
                  </label>
                  <select
                    id="edit-focus"
                    className="form-select"
                    value={focus}
                    onChange={(e) => setFocus(e.target.value as FocusLevel)}
                  >
                    <option value="high">高</option>
                    <option value="medium">中</option>
                    <option value="low">低</option>
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-interrupt">
                    可中断性
                  </label>
                  <select
                    id="edit-interrupt"
                    className="form-select"
                    value={interruptibility}
                    onChange={(e) => setInterruptibility(e.target.value as Interruptibility)}
                  >
                    <option value="low">低</option>
                    <option value="medium">中</option>
                    <option value="high">高</option>
                  </select>
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-location">
                    场所
                  </label>
                  <select
                    id="edit-location"
                    className="form-select"
                    value={location}
                    onChange={(e) => setLocation(e.target.value as LocationType)}
                  >
                    <option value="any">不限</option>
                    <option value="indoor">室内</option>
                    <option value="outdoor">室外</option>
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-device">
                    设备
                  </label>
                  <select
                    id="edit-device"
                    className="form-select"
                    value={device}
                    onChange={(e) => setDevice(e.target.value as DeviceType)}
                  >
                    <option value="any">不限</option>
                    <option value="desktop">桌面</option>
                    <option value="mobile">手机</option>
                  </select>
                </div>
              </div>
              <div className="form-group">
                <label className="form-checkbox-row">
                  <input
                    type="checkbox"
                    checked={parallelizable}
                    onChange={(e) => setParallelizable(e.target.checked)}
                  />
                  可并行执行
                </label>
              </div>
            </div>

            {/* 评分 */}
            <div className="form-section">
              <div className="form-section-title">评分参数</div>
              <div className="form-row">
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-importance">
                    重要度 (0-1)
                  </label>
                  <input
                    id="edit-importance"
                    className="form-input"
                    type="number"
                    min="0"
                    max="1"
                    step="0.1"
                    value={importance}
                    onChange={(e) => setImportance(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="edit-difficulty">
                    难度 (0-1)
                  </label>
                  <input
                    id="edit-difficulty"
                    className="form-input"
                    type="number"
                    min="0"
                    max="1"
                    step="0.1"
                    value={difficulty}
                    onChange={(e) => setDifficulty(e.target.value)}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn-cancel" onClick={onClose}>
              取消
            </button>
            <button type="submit" className="btn-save">
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
