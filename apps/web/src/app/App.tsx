import LoginScreen from "../features/auth/components/LoginScreen";
import {
  fetchWebSessionState,
  fetchWebSessions,
  loginWebOwner,
  logoutWebOwner,
  revokeOtherWebSessions,
  revokeWebSession,
  type WebSessionSummary
} from "../features/auth/data/webAuth";
import SettingsModal from "../features/settings/components/SettingsModal";
import QuickAddDock from "../features/sequence/components/QuickAddDock";
import SequenceTab from "../features/sequence/components/SequenceTab";
import TaskSequenceModal from "../features/sequence/components/TaskSequenceModal";
import SchedulePanel from "../features/schedule/components/SchedulePanel";
import TaskDetailModal from "../features/task-detail/components/TaskDetailModal";
import TaskEditModal from "../features/task-pool/components/TaskEditModal";
import TaskPoolPanel from "../features/task-pool/components/TaskPoolPanel";
import TimeTemplateEditor from "../features/time-template/components/TimeTemplateEditor";
import { ApiError } from "../shared/network/apiClient";
import { applyResolvedTheme, loadThemeMode, resolveThemeMode, saveThemeMode, type ThemeMode } from "../shared/storage/themeStore";
import { useWebAppController, type WebAppTab } from "./useWebAppController";
import { useCallback, useEffect, useMemo, useState } from "react";

const TAB_ORDER: WebAppTab[] = ["sequence", "taskPool", "schedule"];

const TAB_META: Record<WebAppTab, { label: string; title: string }> = {
  sequence: {
    label: "主序列",
    title: "主序列"
  },
  taskPool: {
    label: "任务池",
    title: "任务池"
  },
  schedule: {
    label: "时间视图",
    title: "时间视图"
  }
};

function App() {
  const [themeMode, setThemeMode] = useState<ThemeMode>(loadThemeMode());
  const [prefersDark, setPrefersDark] = useState(() =>
    typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches
  );
  const [authStatus, setAuthStatus] = useState<"checking" | "authenticated" | "unauthenticated" | "submitting">("checking");
  const [loginEnabled, setLoginEnabled] = useState(true);
  const [authError, setAuthError] = useState("");
  const [currentSession, setCurrentSession] = useState<WebSessionSummary | null>(null);
  const [sessions, setSessions] = useState<WebSessionSummary[]>([]);
  const [sessionsBusy, setSessionsBusy] = useState(false);

  const handleUnauthorized = useCallback(() => {
    setCurrentSession(null);
    setSessions([]);
    setAuthStatus("unauthenticated");
    setAuthError("登录已失效");
  }, []);

  const controller = useWebAppController({
    isAuthenticated: authStatus === "authenticated",
    sessionDeviceId: currentSession?.deviceId ?? null,
    onUnauthorized: handleUnauthorized
  });

  const refreshSessionState = useCallback(async () => {
    try {
      const state = await fetchWebSessionState();
      setLoginEnabled(state.enabled);
      if (state.authenticated && state.session) {
        setCurrentSession(state.session);
        setAuthStatus("authenticated");
        setAuthError("");
        return;
      }

      setCurrentSession(null);
      setSessions([]);
      setAuthStatus("unauthenticated");
    } catch (error) {
      setCurrentSession(null);
      setSessions([]);
      setAuthStatus("unauthenticated");
      setAuthError(error instanceof Error ? error.message : String(error));
    }
  }, []);

  const refreshSessions = useCallback(async () => {
    if (authStatus !== "authenticated") return;

    setSessionsBusy(true);
    try {
      const payload = await fetchWebSessions();
      setSessions(payload.sessions);
      setCurrentSession(payload.sessions.find((session) => session.current) ?? currentSession);
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        handleUnauthorized();
      }
    } finally {
      setSessionsBusy(false);
    }
  }, [authStatus, currentSession, handleUnauthorized]);

  useEffect(() => {
    void refreshSessionState();
  }, [refreshSessionState]);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const listener = (event: MediaQueryListEvent) => setPrefersDark(event.matches);
    setPrefersDark(media.matches);
    media.addEventListener("change", listener);
    return () => media.removeEventListener("change", listener);
  }, []);

  const resolvedTheme = useMemo(() => resolveThemeMode(themeMode, prefersDark), [prefersDark, themeMode]);

  useEffect(() => {
    applyResolvedTheme(resolvedTheme);
  }, [resolvedTheme]);

  useEffect(() => {
    if (controller.isSettingsOpen && authStatus === "authenticated") {
      void refreshSessions();
    }
  }, [authStatus, controller.isSettingsOpen, refreshSessions]);

  const activeMeta = TAB_META[controller.currentTab];
  const sequenceActive = controller.currentTab === "sequence";

  const handleLogin = useCallback(
    async (payload: { username: string; password: string; deviceName: string }) => {
      setAuthStatus("submitting");
      setAuthError("");

      try {
        const result = await loginWebOwner(payload);
        setCurrentSession(result.session);
        setAuthStatus("authenticated");
        const sessionPayload = await fetchWebSessions();
        setSessions(sessionPayload.sessions);
      } catch (error) {
        setCurrentSession(null);
        setSessions([]);
        setAuthStatus("unauthenticated");
        setAuthError(error instanceof Error ? error.message : String(error));
      }
    },
    []
  );

  const handleLogout = useCallback(async () => {
    try {
      await logoutWebOwner();
    } finally {
      controller.closeSettings();
      handleUnauthorized();
    }
  }, [controller, handleUnauthorized]);

  const handleRevokeSession = useCallback(
    async (sessionId: string) => {
      try {
        const result = await revokeWebSession(sessionId);
        if (result.currentSessionRevoked) {
          controller.closeSettings();
          handleUnauthorized();
          return;
        }
        await refreshSessions();
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          controller.closeSettings();
          handleUnauthorized();
        }
      }
    },
    [controller, handleUnauthorized, refreshSessions]
  );

  const handleRevokeOtherSessions = useCallback(async () => {
    try {
      await revokeOtherWebSessions();
      await refreshSessions();
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        controller.closeSettings();
        handleUnauthorized();
      }
    }
  }, [controller, handleUnauthorized, refreshSessions]);

  const handleSaveSettings = useCallback(
    (hideCompletedTasks: boolean, nextThemeMode: ThemeMode) => {
      controller.saveSettings(hideCompletedTasks);
      setThemeMode(saveThemeMode(nextThemeMode));
    },
    [controller]
  );

  const openSettings = useCallback(() => {
    controller.openSettings();
    void refreshSessions();
  }, [controller, refreshSessions]);

  if (authStatus === "checking") {
    return (
      <main className="auth-shell">
        <div className="shell-background" />
        <section className="auth-card compact-auth-card">载入中</section>
      </main>
    );
  }

  if (authStatus !== "authenticated") {
    return (
      <LoginScreen
        isSubmitting={authStatus === "submitting"}
        errorMessage={authError}
        loginEnabled={loginEnabled}
        onSubmit={handleLogin}
      />
    );
  }

  return (
    <main className={`app-shell${sequenceActive ? " sequence-active" : ""}`}>
      <div className="shell-background" />
      <div className="safe-area-scrim top" />

      <div className="shell-layout">
        <header className="shell-header">
          <h1>{activeMeta.title}</h1>
          <div className="sync-area shell-sync-area">
            <span
              className={`sync-dot ${controller.syncState === "syncing" ? "syncing" : controller.syncState === "error" ? "error" : ""}`}
            />
            <span className="sync-text">{controller.syncMessage}</span>
          </div>
        </header>

        <nav className="tab-switcher" aria-label="主导航">
          {TAB_ORDER.map((tab) => (
            <button
              key={tab}
              className={`tab-switcher-button${controller.currentTab === tab ? " active" : ""}`}
              onClick={() => controller.setCurrentTab(tab)}
            >
              <span className="tab-switcher-label">{TAB_META[tab].label}</span>
            </button>
          ))}
        </nav>

        <section className="shell-panel">
          {controller.currentTab === "sequence" && (
            <SequenceTab
              focusedTask={controller.focusedTask}
              primarySequenceTasks={controller.primarySequenceTasks}
              nextTasks={controller.nextTasks}
              getCurrentStepForTask={controller.getCurrentStepForTask}
              onTaskTap={controller.openTaskDetail}
              onTaskComplete={(task) => controller.toggleDone(task.id)}
              onTaskEdit={controller.openTaskEditor}
              onTaskArchive={(task) => controller.archiveTask(task.id)}
              onTaskDelete={(task) => controller.deleteTask(task.id)}
              onReorderPrimarySequence={controller.reorderPrimarySequence}
            />
          )}

          {controller.currentTab === "taskPool" && (
            <TaskPoolPanel
              tasks={controller.filteredTasks}
              organization={controller.taskPoolOrganization}
              syncMessage={controller.syncMessage}
              isSyncing={controller.isSyncing}
              onRefresh={() => void controller.performSync()}
              onOpenSettings={openSettings}
              onExport={controller.exportMarkdown}
              onImport={controller.importMarkdownFile}
              onOpenTask={controller.openTaskDetail}
              onCreateDirectory={controller.createTaskPoolDirectory}
              onRenameDirectory={controller.renameTaskPoolDirectory}
              onDeleteDirectory={controller.deleteTaskPoolDirectory}
              onMoveDirectory={controller.moveTaskPoolDirectory}
              onPlaceTask={controller.placeTaskInTaskPool}
              onUpdateCanvasNode={controller.updateTaskPoolCanvasNode}
              onResetCanvasLayout={controller.resetTaskPoolCanvasLayout}
            />
          )}

          {controller.currentTab === "schedule" && (
            <div className="stack-layout">
              <section className="card shell-subcard">
                <div className="panel-header">
                  <div className="panel-title">时间模板</div>
                  <div className="toolbar compact-toolbar">
                    <button className="btn-text" onClick={controller.resetTimeTemplate}>
                      重置模板
                    </button>
                    <button className="btn-text" onClick={controller.toggleTemplateOpen}>
                      {controller.templateOpen ? "收起" : "展开"}
                    </button>
                  </div>
                </div>

                {controller.templateOpen && (
                  <TimeTemplateEditor
                    timeTemplate={controller.timeTemplate}
                    onAddRange={controller.addRange}
                    onUpdateRange={controller.updateRange}
                    onRemoveRange={controller.removeRange}
                  />
                )}
              </section>

              <SchedulePanel
                horizonDays={controller.horizonDays}
                onChangeHorizon={controller.setHorizonDays}
                scheduleView={controller.scheduleView}
                blocksByDay={controller.blocksByDay}
              />
            </div>
          )}
        </section>
      </div>

      {sequenceActive && (
        <>
          <div className="safe-area-scrim bottom" />
          <QuickAddDock
            value={controller.quickInput}
            onChange={controller.setQuickInput}
            onSubmit={controller.addTask}
            onOpenDetail={controller.openQuickAddEditor}
            onOpenSequence={controller.openQuickAddSequence}
          />
        </>
      )}

      {controller.editingTask && (
        <TaskEditModal
          task={controller.editingTask}
          allTasks={controller.visibleTasks}
          onSave={controller.saveEditedTask}
          onClose={controller.closeTaskEditor}
        />
      )}

      {controller.taskSequenceDraft && (
        <TaskSequenceModal
          draft={controller.taskSequenceDraft}
          onSave={controller.saveTaskSequenceDraft}
          onClose={controller.closeTaskSequence}
        />
      )}

      {controller.selectedTask && (
        <TaskDetailModal
          task={controller.selectedTask}
          currentStep={controller.getCurrentStepForTask(controller.selectedTask)}
          onClose={controller.closeTaskDetail}
          onEdit={() => controller.openTaskEditor(controller.selectedTask!)}
          onToggleCompletion={() => controller.toggleDone(controller.selectedTask!.id)}
          onArchive={() => controller.archiveTask(controller.selectedTask!.id)}
          onPromoteToDoing={() => controller.promoteTaskToDoing(controller.selectedTask!.id)}
          onAddStep={(title) => controller.appendTaskStep(controller.selectedTask!.id, title)}
          onCompleteCurrentStep={(stepId) => controller.completeTaskStep(controller.selectedTask!.id, stepId)}
        />
      )}

      {controller.isSettingsOpen && (
        <SettingsModal
          hideCompletedTasks={controller.hideCompletedTasks}
          themeMode={themeMode}
          syncMessage={controller.syncMessage}
          syncState={controller.syncState}
          currentSession={currentSession}
          sessions={sessions}
          sessionsBusy={sessionsBusy}
          onSave={handleSaveSettings}
          onRefreshSessions={() => void refreshSessions()}
          onLogout={() => void handleLogout()}
          onRevokeSession={(sessionId) => void handleRevokeSession(sessionId)}
          onRevokeOtherSessions={() => void handleRevokeOtherSessions()}
          onClose={controller.closeSettings}
        />
      )}
    </main>
  );
}

export default App;
