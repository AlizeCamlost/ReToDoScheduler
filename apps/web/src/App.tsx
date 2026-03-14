import {
  DEFAULT_TIME_TEMPLATE,
  buildQuickTask,
  buildSchedulePresentation,
  makeTask,
  type Task,
  type TimeTemplate,
  type WeeklyTimeRange
} from "@retodo/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import SchedulePanel from "./components/SchedulePanel";
import TaskEditModal from "./components/TaskEditModal";
import TaskPoolPanel from "./components/TaskPoolPanel";
import TimeTemplateEditor from "./components/TimeTemplateEditor";
import { API_BASE_URL } from "./config";
import { downloadMarkdown, getOrCreateDeviceId, loadTimeTemplate, parseMarkdownImport, saveTimeTemplate } from "./storage";
import { pullRemoteTasks, pushAndPullTasks } from "./sync";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [quickInput, setQuickInput] = useState("");
  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [horizonDays, setHorizonDays] = useState<number>(7);
  const [searchQuery, setSearchQuery] = useState("");
  const [templateOpen, setTemplateOpen] = useState(false);
  const [timeTemplate, setTimeTemplate] = useState<TimeTemplate>(loadTimeTemplate());
  const [syncMessage, setSyncMessage] = useState("未同步");
  const [isSyncing, setIsSyncing] = useState(false);

  const tasksRef = useRef(tasks);
  const deviceIdRef = useRef(getOrCreateDeviceId());
  const syncInFlightRef = useRef(false);

  useEffect(() => {
    tasksRef.current = tasks;
  }, [tasks]);

  useEffect(() => {
    saveTimeTemplate(timeTemplate);
  }, [timeTemplate]);

  const visibleTasks = useMemo(() => tasks.filter((task) => task.status !== "archived"), [tasks]);

  const schedulePresentation = useMemo(
    () => buildSchedulePresentation(visibleTasks, timeTemplate, horizonDays),
    [visibleTasks, timeTemplate, horizonDays]
  );
  const { scheduleView, blocksByDay } = schedulePresentation;

  const orderedTaskIds = useMemo(() => {
    const ids = new Set<string>();
    for (const step of scheduleView.orderedSteps) ids.add(step.taskId);
    return [...ids];
  }, [scheduleView.orderedSteps]);

  const filteredTasks = useMemo(() => {
    const byId = new Map(visibleTasks.map((task) => [task.id, task]));
    const ordered = orderedTaskIds.map((taskId) => byId.get(taskId)).filter((task): task is Task => Boolean(task));
    const missing = visibleTasks.filter((task) => !orderedTaskIds.includes(task.id));
    const merged = [...ordered, ...missing];

    if (!searchQuery.trim()) return merged;

    const query = searchQuery.trim().toLowerCase();
    return merged.filter(
      (task) =>
        task.title.toLowerCase().includes(query) ||
        (task.description ?? "").toLowerCase().includes(query) ||
        task.tags.some((tag) => tag.toLowerCase().includes(query))
    );
  }, [orderedTaskIds, searchQuery, visibleTasks]);

  const applyRemoteTasks = useCallback((incoming: Task[]) => {
    setTasks(incoming);
    tasksRef.current = incoming;
  }, []);

  const performSync = useCallback(
    async (tasksToPush?: Task[]) => {
      if (syncInFlightRef.current) return;
      syncInFlightRef.current = true;
      setIsSyncing(true);
      try {
        const remote = await pushAndPullTasks(API_BASE_URL, deviceIdRef.current, tasksToPush ?? tasksRef.current);
        applyRemoteTasks(remote);
        setSyncMessage(`已同步 ${new Date().toLocaleTimeString()}`);
      } catch (error) {
        setSyncMessage(`同步失败: ${error instanceof Error ? error.message : String(error)}`);
      } finally {
        syncInFlightRef.current = false;
        setIsSyncing(false);
      }
    },
    [applyRemoteTasks]
  );

  const pullOnly = useCallback(async () => {
    if (syncInFlightRef.current) return;
    try {
      const remote = await pullRemoteTasks(API_BASE_URL);
      applyRemoteTasks(remote);
      setSyncMessage(`已拉取 ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setSyncMessage(`拉取失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }, [applyRemoteTasks]);

  const commitTasks = useCallback(
    (next: Task[]) => {
      setTasks(next);
      tasksRef.current = next;
      void performSync(next);
    },
    [performSync]
  );

  useEffect(() => {
    void pullOnly();
  }, [pullOnly]);

  useEffect(() => {
    const timer = window.setInterval(() => void pullOnly(), 7000);
    return () => window.clearInterval(timer);
  }, [pullOnly]);

  const addTask = () => {
    if (!quickInput.trim()) return;
    const nextTask = buildQuickTask(createId(), quickInput);

    commitTasks([nextTask, ...tasks]);
    setQuickInput("");
  };

  const toggleDone = (taskId: string) => {
    commitTasks(
      tasks.map((task) =>
        task.id === taskId
          ? makeTask({
              ...task,
              status: task.status === "done" ? "todo" : "done",
              updatedAt: new Date().toISOString()
            })
          : task
      )
    );
  };

  const archiveTask = (taskId: string) => {
    commitTasks(
      tasks.map((task) =>
        task.id === taskId ? makeTask({ ...task, status: "archived", updatedAt: new Date().toISOString() }) : task
      )
    );
  };

  const saveEditedTask = (updated: Task) => {
    commitTasks(tasks.map((task) => (task.id === updated.id ? updated : task)));
    setEditingTask(null);
  };

  const importMarkdown = async (file: File | null) => {
    if (!file) return;
    const text = await file.text();
    const lines = parseMarkdownImport(text);
    if (lines.length === 0) return;

    const imported = lines.map((line) => {
      return buildQuickTask(createId(), line);
    });

    commitTasks([...imported, ...tasks]);
  };

  const updateRange = (rangeId: string, patch: Partial<WeeklyTimeRange>) => {
    setTimeTemplate((current) => ({
      ...current,
      weeklyRanges: current.weeklyRanges.map((range) => (range.id === rangeId ? { ...range, ...patch } : range))
    }));
  };

  const addRange = () => {
    const nextId = createId();
    setTimeTemplate((current) => ({
      ...current,
      weeklyRanges: [
        ...current.weeklyRanges,
        {
          id: nextId,
          weekday: 1,
          startTime: "09:00",
          endTime: "10:00"
        }
      ]
    }));
  };

  const removeRange = (rangeId: string) => {
    setTimeTemplate((current) => ({
      ...current,
      weeklyRanges: current.weeklyRanges.filter((range) => range.id !== rangeId)
    }));
  };

  return (
    <main className="app">
      <header className="header">
        <div className="header-left">
          <h1>任务池</h1>
          <span className="task-count">{visibleTasks.filter((task) => task.status !== "done").length} 项待办</span>
        </div>
        <div className="sync-area">
          <span className={`sync-dot ${isSyncing ? "syncing" : syncMessage.startsWith("同步失败") || syncMessage.startsWith("拉取失败") ? "error" : ""}`} />
          <span className="sync-text">{syncMessage}</span>
          <button className="btn-icon" onClick={() => void performSync()} disabled={isSyncing} title="立即同步">
            {isSyncing ? "..." : "↻"}
          </button>
        </div>
      </header>

      <section className="card">
        <div className="input-area">
          <input
            className="input-main"
            type="text"
            value={quickInput}
            onChange={(event) => setQuickInput(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") addTask();
            }}
            placeholder="输入任务，例如：周报 90分钟 明天 #工作"
          />
          <button className="btn-add" onClick={addTask}>
            添加
          </button>
        </div>

        <div className="toolbar">
          <button className="btn-text" onClick={() => setTemplateOpen((current) => !current)}>
            {templateOpen ? "收起时间模板" : "时间模板"}
          </button>
          <button className="btn-text" onClick={() => downloadMarkdown(visibleTasks)}>
            导出
          </button>
          <button className="btn-text" onClick={() => setTimeTemplate(DEFAULT_TIME_TEMPLATE)}>
            重置模板
          </button>
          <label className="file-label">
            导入
            <input type="file" accept=".md,text/markdown" onChange={(event) => void importMarkdown(event.target.files?.[0] ?? null)} />
          </label>
        </div>

        {templateOpen && (
          <TimeTemplateEditor
            timeTemplate={timeTemplate}
            onAddRange={addRange}
            onUpdateRange={updateRange}
            onRemoveRange={removeRange}
          />
        )}
      </section>

      <SchedulePanel
        horizonDays={horizonDays}
        onChangeHorizon={setHorizonDays}
        scheduleView={scheduleView}
        blocksByDay={blocksByDay}
      />

      <TaskPoolPanel
        tasks={filteredTasks}
        searchQuery={searchQuery}
        onSearchQueryChange={setSearchQuery}
        onToggleDone={toggleDone}
        onArchive={archiveTask}
        onEdit={setEditingTask}
      />

      {editingTask && (
        <TaskEditModal task={editingTask} allTasks={tasks} onSave={saveEditedTask} onClose={() => setEditingTask(null)} />
      )}
    </main>
  );
}

export default App;
