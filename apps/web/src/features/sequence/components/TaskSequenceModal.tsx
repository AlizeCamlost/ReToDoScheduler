import { parseQuickInput } from "@retodo/core";
import { type FormEvent, useEffect, useMemo, useRef, useState } from "react";
import type { WebTaskSequenceDraft } from "../../../app/useWebAppController";

interface TaskSequenceModalProps {
  draft: WebTaskSequenceDraft;
  onSave: (draft: WebTaskSequenceDraft) => void;
  onClose: () => void;
}

export default function TaskSequenceModal({ draft, onSave, onClose }: TaskSequenceModalProps) {
  const [title, setTitle] = useState(draft.title);
  const [entries, setEntries] = useState<string[]>(
    draft.entries.length > 0 ? draft.entries : [""]
  );
  const overlayRef = useRef<HTMLDivElement>(null);
  const firstEntryRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    firstEntryRef.current?.focus();
  }, []);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const canSave = useMemo(
    () => entries.some((entry) => entry.trim().length > 0),
    [entries]
  );

  const handleOverlayClick = (event: React.MouseEvent) => {
    if (event.target === overlayRef.current) onClose();
  };

  const updateEntry = (index: number, value: string) => {
    setEntries((current) => current.map((entry, currentIndex) => (currentIndex === index ? value : entry)));
  };

  const appendEntry = () => {
    setEntries((current) => [...current, ""]);
  };

  const removeEntry = (index: number) => {
    setEntries((current) => {
      const next = current.filter((_, currentIndex) => currentIndex !== index);
      return next.length > 0 ? next : [""];
    });
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    onSave({
      title: title.trim(),
      entries
    });
  };

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal detail-modal" role="dialog" aria-label="任务序列">
        <div className="modal-header">
          <h2>任务序列</h2>
          <button className="btn-close" onClick={onClose} title="关闭">
            ×
          </button>
        </div>

        <form className="modal-form" onSubmit={handleSubmit}>
          <div className="modal-body detail-modal-body">
            <section className="detail-panel">
              <div className="form-group">
                <label className="form-label" htmlFor="sequence-title">
                  序列标签（可选）
                </label>
                <input
                  id="sequence-title"
                  className="form-input"
                  value={title}
                  onChange={(event) => setTitle(event.target.value)}
                  placeholder="例如：今天上午 / 上线收尾"
                />
              </div>
            </section>

            <section className="detail-panel">
              <div className="form-section-header">
                <div className="detail-panel-title">任务描述</div>
                <button type="button" className="btn-text" onClick={appendEntry}>
                  继续添加
                </button>
              </div>

              <div className="sequence-entry-list">
                {entries.map((entry, index) => {
                  const preview = entry.trim() ? parseQuickInput(entry.trim()) : null;
                  return (
                    <div key={`${index}-${entries.length}`} className="sequence-entry-card">
                      <div className="sequence-entry-header">
                        <span className="sequence-entry-label">第 {index + 1} 项</span>
                        {entries.length > 1 && (
                          <button type="button" className="btn-text danger-text" onClick={() => removeEntry(index)}>
                            删除
                          </button>
                        )}
                      </div>

                      <textarea
                        ref={index === 0 ? firstEntryRef : undefined}
                        className="form-textarea sequence-entry-input"
                        value={entry}
                        onChange={(event) => updateEntry(index, event.target.value)}
                        rows={3}
                        placeholder="例如：整理晨会纪要 #team 20m"
                      />

                      {preview ? (
                        <div className="sequence-entry-preview">
                          <span>{preview.title}</span>
                          <span>{preview.estimatedMinutes} 分钟</span>
                          {preview.tags.length > 0 && <span>{preview.tags.slice(0, 2).map((tag) => `#${tag}`).join(" ")}</span>}
                        </div>
                      ) : null}
                    </div>
                  );
                })}
              </div>
            </section>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>
              取消
            </button>
            <button type="submit" className="btn-primary" disabled={!canSave}>
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
