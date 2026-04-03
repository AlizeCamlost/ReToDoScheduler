import { type FormEvent, useEffect, useRef, useState } from "react";
import type { WebSyncSettings } from "../../../shared/storage/syncSettingsStore";

interface SyncSettingsModalProps {
  settings: WebSyncSettings;
  hideCompletedTasks: boolean;
  syncMessage: string;
  syncState: "idle" | "syncing" | "error" | "notConfigured";
  onSave: (settings: WebSyncSettings, hideCompletedTasks: boolean) => void;
  onClose: () => void;
}

export default function SyncSettingsModal({
  settings,
  hideCompletedTasks,
  syncMessage,
  syncState,
  onSave,
  onClose
}: SyncSettingsModalProps) {
  const [draft, setDraft] = useState<WebSyncSettings>(settings);
  const [hideCompleted, setHideCompleted] = useState(hideCompletedTasks);
  const overlayRef = useRef<HTMLDivElement>(null);
  const baseUrlRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    baseUrlRef.current?.focus();
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
    onSave(draft, hideCompleted);
  };

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal" role="dialog" aria-label="同步设置">
        <div className="modal-header">
          <h2>设置</h2>
          <button className="btn-close" onClick={onClose} title="关闭">
            ×
          </button>
        </div>

        <form className="modal-form" onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-section">
              <div className="form-section-title">连接信息</div>
              <div className="form-group">
                <label className="form-label" htmlFor="sync-base-url">
                  API Base URL
                </label>
                <input
                  ref={baseUrlRef}
                  id="sync-base-url"
                  className="form-input"
                  value={draft.baseUrl}
                  onChange={(event) => setDraft((current) => ({ ...current, baseUrl: event.target.value }))}
                  placeholder="https://api.example.com"
                />
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="sync-auth-token">
                  API Auth Token
                </label>
                <input
                  id="sync-auth-token"
                  className="form-input"
                  type="password"
                  value={draft.authToken}
                  onChange={(event) => setDraft((current) => ({ ...current, authToken: event.target.value }))}
                  placeholder="与服务端一致的 token"
                />
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="sync-device-id">
                  Device ID（留空自动生成）
                </label>
                <input
                  id="sync-device-id"
                  className="form-input"
                  value={draft.deviceId}
                  onChange={(event) => setDraft((current) => ({ ...current, deviceId: event.target.value }))}
                  placeholder="浏览器设备标识"
                />
              </div>
            </div>

            <div className="form-section">
              <div className="form-section-title">当前状态</div>
              <div className={`settings-status-card state-${syncState}`}>
                <div className="settings-status-title">
                  {syncState === "syncing"
                    ? "正在同步"
                    : syncState === "error"
                      ? "同步失败"
                      : syncState === "notConfigured"
                        ? "尚未配置同步"
                        : "同步已就绪"}
                </div>
                <div className="helper-text">{syncMessage}</div>
              </div>
            </div>

            <div className="form-section">
              <div className="form-section-title">显示设置</div>
              <label className="form-checkbox-row" htmlFor="hide-completed-tasks">
                <input
                  id="hide-completed-tasks"
                  type="checkbox"
                  checked={hideCompleted}
                  onChange={(event) => setHideCompleted(event.target.checked)}
                />
                <span>隐藏已完成任务</span>
              </label>
              <div className="helper-text">
                当前开关会作用于任务池内容视图；Sequence 和 Schedule 不跟着隐藏。
              </div>
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
