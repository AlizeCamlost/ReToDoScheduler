import SchedulePanel from "../features/schedule/components/SchedulePanel";
import TaskEditModal from "../features/task-pool/components/TaskEditModal";
import TaskPoolPanel from "../features/task-pool/components/TaskPoolPanel";
import TimeTemplateEditor from "../features/time-template/components/TimeTemplateEditor";
import { useWebAppController } from "./useWebAppController";

function App() {
  const controller = useWebAppController();

  return (
    <main className="app">
      <header className="header">
        <div className="header-left">
          <h1>任务池</h1>
          <span className="task-count">{controller.visibleTasks.filter((task) => task.status !== "done").length} 项待办</span>
        </div>
        <div className="sync-area">
          <span
            className={`sync-dot ${controller.isSyncing ? "syncing" : controller.syncMessage.startsWith("同步失败") || controller.syncMessage.startsWith("拉取失败") ? "error" : ""}`}
          />
          <span className="sync-text">{controller.syncMessage}</span>
          <button className="btn-icon" onClick={() => void controller.performSync()} disabled={controller.isSyncing} title="立即同步">
            {controller.isSyncing ? "..." : "↻"}
          </button>
        </div>
      </header>

      <section className="card">
        <div className="input-area">
          <input
            className="input-main"
            type="text"
            value={controller.quickInput}
            onChange={(event) => controller.setQuickInput(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") controller.addTask();
            }}
            placeholder="输入任务，例如：周报 90分钟 明天 #工作"
          />
          <button className="btn-add" onClick={controller.addTask}>
            添加
          </button>
        </div>

        <div className="toolbar">
          <button className="btn-text" onClick={controller.toggleTemplateOpen}>
            {controller.templateOpen ? "收起时间模板" : "时间模板"}
          </button>
          <button className="btn-text" onClick={controller.exportMarkdown}>
            导出
          </button>
          <button className="btn-text" onClick={controller.resetTimeTemplate}>
            重置模板
          </button>
          <label className="file-label">
            导入
            <input
              type="file"
              accept=".md,text/markdown"
              onChange={(event) => void controller.importMarkdownFile(event.target.files?.[0] ?? null)}
            />
          </label>
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

      <TaskPoolPanel
        tasks={controller.filteredTasks}
        searchQuery={controller.searchQuery}
        onSearchQueryChange={controller.setSearchQuery}
        onToggleDone={controller.toggleDone}
        onArchive={controller.archiveTask}
        onEdit={controller.openTaskEditor}
      />

      {controller.editingTask && (
        <TaskEditModal
          task={controller.editingTask}
          allTasks={controller.visibleTasks}
          onSave={controller.saveEditedTask}
          onClose={controller.closeTaskEditor}
        />
      )}
    </main>
  );
}

export default App;
