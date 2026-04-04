import { type MouseEvent, type ReactNode, useEffect, useRef, useState } from "react";
import type { WebSessionSummary } from "../../auth/data/webAuth";
import type { ThemeMode } from "../../../shared/storage/themeStore";

interface SettingsModalProps {
  hideCompletedTasks: boolean;
  themeMode: ThemeMode;
  syncMessage: string;
  syncState: "idle" | "syncing" | "error";
  currentSession: WebSessionSummary | null;
  sessions: WebSessionSummary[];
  sessionsBusy: boolean;
  onSave: (hideCompletedTasks: boolean, themeMode: ThemeMode) => void;
  onRefreshSessions: () => void;
  onLogout: () => void;
  onRevokeSession: (sessionId: string) => void;
  onRevokeOtherSessions: () => void;
  onClose: () => void;
}

const THEME_OPTIONS: Array<{ value: ThemeMode; label: string }> = [
  { value: "system", label: "跟随系统" },
  { value: "light", label: "浅色" },
  { value: "dark", label: "深色" }
];

const formatTimestamp = (value: string): string =>
  new Date(value).toLocaleString("zh-CN", {
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });

const renderSessionMeta = (session: WebSessionSummary): ReactNode => {
  const parts = [
    `最近 ${formatTimestamp(session.lastSeenAt)}`,
    session.ipAddress || null,
    session.userAgent || null
  ].filter(Boolean);

  return parts.join(" · ");
};

export default function SettingsModal({
  hideCompletedTasks,
  themeMode,
  syncMessage,
  syncState,
  currentSession,
  sessions,
  sessionsBusy,
  onSave,
  onRefreshSessions,
  onLogout,
  onRevokeSession,
  onRevokeOtherSessions,
  onClose
}: SettingsModalProps) {
  const [hideCompletedDraft, setHideCompletedDraft] = useState(hideCompletedTasks);
  const [themeDraft, setThemeDraft] = useState(themeMode);
  const overlayRef = useRef<HTMLDivElement>(null);
  const firstThemeButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    setHideCompletedDraft(hideCompletedTasks);
  }, [hideCompletedTasks]);

  useEffect(() => {
    setThemeDraft(themeMode);
  }, [themeMode]);

  useEffect(() => {
    firstThemeButtonRef.current?.focus();
  }, []);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const handleOverlayClick = (event: MouseEvent<HTMLDivElement>) => {
    if (event.target === overlayRef.current) onClose();
  };

  const currentSessions = sessions.filter((session) => session.current);
  const otherSessions = sessions.filter((session) => !session.current);

  return (
    <div className="modal-overlay" ref={overlayRef} onClick={handleOverlayClick}>
      <div className="modal" role="dialog" aria-label="设置">
        <div className="modal-header">
          <h2>设置</h2>
          <button className="btn-close" onClick={onClose} title="关闭">
            ×
          </button>
        </div>

        <div className="modal-body settings-modal-body">
          <section className="settings-section">
            <div className="settings-section-header">
              <div className="form-section-title">外观</div>
            </div>
            <div className="theme-toggle" role="radiogroup" aria-label="外观模式">
              {THEME_OPTIONS.map((option, index) => (
                <button
                  key={option.value}
                  ref={index === 0 ? firstThemeButtonRef : undefined}
                  type="button"
                  className={`theme-toggle-option${themeDraft === option.value ? " active" : ""}`}
                  aria-pressed={themeDraft === option.value}
                  onClick={() => setThemeDraft(option.value)}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </section>

          <section className="settings-section">
            <div className="settings-section-header">
              <div className="form-section-title">任务池</div>
            </div>
            <label className="form-checkbox-row" htmlFor="hide-completed-tasks">
              <input
                id="hide-completed-tasks"
                type="checkbox"
                checked={hideCompletedDraft}
                onChange={(event) => setHideCompletedDraft(event.target.checked)}
              />
              <span>隐藏已完成任务</span>
            </label>
          </section>

          <section className="settings-section">
            <div className="settings-section-header">
              <div className="form-section-title">同步</div>
            </div>
            <div className={`settings-status-card state-${syncState}`}>
              <div className="settings-status-title">{syncMessage}</div>
              {currentSession && <div className="settings-status-meta">{currentSession.deviceName}</div>}
            </div>
          </section>

          <section className="settings-section">
            <div className="settings-section-header">
              <div className="form-section-title">设备</div>
              <div className="toolbar compact-toolbar settings-section-actions">
                <button type="button" className="btn-text" onClick={onRefreshSessions} disabled={sessionsBusy}>
                  {sessionsBusy ? "刷新中" : "刷新设备"}
                </button>
                <button
                  type="button"
                  className="btn-text"
                  onClick={onRevokeOtherSessions}
                  disabled={otherSessions.length === 0 || sessionsBusy}
                >
                  退出其他设备
                </button>
              </div>
            </div>

            <div className="session-list">
              {currentSessions.map((session) => (
                <div key={session.id} className="session-card current">
                  <div className="session-card-header">
                    <div className="session-card-title-row">
                      <div className="session-card-title">{session.deviceName}</div>
                      <span className="session-badge">当前设备</span>
                    </div>
                    <button type="button" className="btn-text danger-text" onClick={onLogout}>
                      退出
                    </button>
                  </div>
                  <div className="session-card-meta">{renderSessionMeta(session)}</div>
                </div>
              ))}

              {otherSessions.map((session) => (
                <div key={session.id} className="session-card">
                  <div className="session-card-header">
                    <div className="session-card-title">{session.deviceName}</div>
                    <button
                      type="button"
                      className="btn-text danger-text"
                      onClick={() => onRevokeSession(session.id)}
                    >
                      退出
                    </button>
                  </div>
                  <div className="session-card-meta">{renderSessionMeta(session)}</div>
                </div>
              ))}

              {sessions.length === 0 && <div className="empty-panel">暂无设备</div>}
            </div>
          </section>
        </div>

        <div className="modal-footer">
          <button type="button" className="btn-secondary" onClick={onClose}>
            取消
          </button>
          <button type="button" className="btn-primary" onClick={() => onSave(hideCompletedDraft, themeDraft)}>
            保存
          </button>
        </div>
      </div>
    </div>
  );
}
