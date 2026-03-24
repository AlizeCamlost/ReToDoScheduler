import QuickAddDock from "../features/sequence/components/QuickAddDock";
import SequenceTab from "../features/sequence/components/SequenceTab";
import SchedulePanel from "../features/schedule/components/SchedulePanel";
import TaskDetailModal from "../features/task-detail/components/TaskDetailModal";
import TaskEditModal from "../features/task-pool/components/TaskEditModal";
import TaskPoolPanel from "../features/task-pool/components/TaskPoolPanel";
import TimeTemplateEditor from "../features/time-template/components/TimeTemplateEditor";
import { useWebAppController, type WebAppTab } from "./useWebAppController";

const TAB_META: Record<WebAppTab, { label: string; title: string; description: string }> = {
  sequence: {
    label: "主序列",
    title: "现在先做什么",
    description: "把当前聚焦、主序列和接下来拆开看，先收敛到可执行顺序。"
  },
  schedule: {
    label: "时间视图",
    title: "观察窗口内的滚动排程",
    description: "时间块按当前任务池和时间模板即时重算，不维护一份静态日历。"
  },
  taskPool: {
    label: "任务池",
    title: "维护任务、依赖和步骤",
    description: "所有输入都先沉淀进任务池，再决定何时推进、何时排入。"
  }
};

function App() {
  const controller = useWebAppController();
  const remainingTasks = controller.visibleTasks.filter((task) => task.status !== "done").length;
  const activeMeta = TAB_META[controller.currentTab];
  const sequenceActive = controller.currentTab === "sequence";

  return (
    <main className={`app-shell${sequenceActive ? " sequence-active" : ""}`}>
      <div className="shell-background" />
      <div className="safe-area-scrim top" />

      <div className="shell-layout">
        <header className="shell-header">
          <div className="shell-header-copy">
            <div className="shell-kicker">Norn</div>
            <h1>{activeMeta.title}</h1>
            <p>{activeMeta.description}</p>
          </div>

          <div className="shell-status-cluster">
            <div className="header-metric">
              <span className="header-metric-value">{remainingTasks}</span>
              <span className="header-metric-label">项仍在视野中</span>
            </div>

            <div className="sync-area shell-sync-area">
              <span
                className={`sync-dot ${controller.isSyncing ? "syncing" : controller.syncMessage.startsWith("同步失败") || controller.syncMessage.startsWith("拉取失败") ? "error" : ""}`}
              />
              <span className="sync-text">{controller.syncMessage}</span>
              <button className="btn-icon subtle" onClick={() => void controller.performSync()} disabled={controller.isSyncing} title="立即同步">
                {controller.isSyncing ? "..." : "↻"}
              </button>
            </div>
          </div>
        </header>

        <nav className="tab-switcher" aria-label="主导航">
          {(Object.keys(TAB_META) as WebAppTab[]).map((tab) => (
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
              onReorderPrimarySequence={controller.reorderPrimarySequence}
            />
          )}

          {controller.currentTab === "schedule" && (
            <div className="stack-layout">
              <section className="card shell-subcard">
                <div className="panel-header">
                  <div>
                    <div className="panel-title">时间模板</div>
                    <div className="panel-caption">日程容量仍由周模板提供，先在这里维护，再看排程结果。</div>
                  </div>
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

          {controller.currentTab === "taskPool" && (
            <TaskPoolPanel
              tasks={controller.filteredTasks}
              searchQuery={controller.searchQuery}
              onSearchQueryChange={controller.setSearchQuery}
              onToggleDone={controller.toggleDone}
              onArchive={controller.archiveTask}
              syncMessage={controller.syncMessage}
              isSyncing={controller.isSyncing}
              onRefresh={() => void controller.performSync()}
              onExport={controller.exportMarkdown}
              onImport={controller.importMarkdownFile}
              onOpenDetail={controller.openTaskDetail}
              onEdit={controller.openTaskEditor}
            />
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
    </main>
  );
}

export default App;
