import { type FormEvent, useEffect, useRef, useState } from "react";

interface TaskPoolDirectoryModalProps {
  title: string;
  initialName?: string;
  submitLabel: string;
  onSubmit: (name: string) => void;
  onClose: () => void;
}

export default function TaskPoolDirectoryModal({
  title,
  initialName = "",
  submitLabel,
  onSubmit,
  onClose
}: TaskPoolDirectoryModalProps) {
  const [name, setName] = useState(initialName);
  const overlayRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
    inputRef.current?.select();
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
    const normalized = name.trim();
    if (!normalized) return;
    onSubmit(normalized);
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
              <label className="form-label" htmlFor="task-pool-directory-name">
                目录名称
              </label>
              <input
                ref={inputRef}
                id="task-pool-directory-name"
                className="form-input"
                value={name}
                onChange={(event) => setName(event.target.value)}
                placeholder="输入目录名称"
              />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>
              取消
            </button>
            <button type="submit" className="btn-primary" disabled={!name.trim()}>
              {submitLabel}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
