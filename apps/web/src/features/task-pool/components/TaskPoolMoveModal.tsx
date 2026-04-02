import { type FormEvent, useEffect, useRef, useState } from "react";

export interface TaskPoolMoveOption {
  id: string;
  label: string;
}

interface TaskPoolMoveModalProps {
  title: string;
  options: TaskPoolMoveOption[];
  initialTargetId: string;
  submitLabel: string;
  onSubmit: (targetId: string) => void;
  onClose: () => void;
}

export default function TaskPoolMoveModal({
  title,
  options,
  initialTargetId,
  submitLabel,
  onSubmit,
  onClose
}: TaskPoolMoveModalProps) {
  const [targetId, setTargetId] = useState(initialTargetId);
  const overlayRef = useRef<HTMLDivElement>(null);
  const selectRef = useRef<HTMLSelectElement>(null);

  useEffect(() => {
    selectRef.current?.focus();
  }, []);

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

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    onSubmit(targetId);
  };

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal" role="dialog" aria-label={title}>
        <div className="modal-header">
          <h2>{title}</h2>
          <button className="btn-close" onClick={onClose} title="关闭">
            ×
          </button>
        </div>

        <form className="modal-form" onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-group">
              <label className="form-label" htmlFor="task-pool-move-target">
                目标目录
              </label>
              <select
                ref={selectRef}
                id="task-pool-move-target"
                className="form-select"
                value={targetId}
                onChange={(event) => setTargetId(event.target.value)}
              >
                {options.map((option) => (
                  <option key={option.id} value={option.id}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>
              取消
            </button>
            <button type="submit" className="btn-primary">
              {submitLabel}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
