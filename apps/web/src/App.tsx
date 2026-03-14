import {
  DEFAULT_TIME_TEMPLATE,
  createDefaultComparator,
  makeTask,
  parseQuickInput,
  refreshSchedule,
  type ScheduleBlock,
  type Task,
  type TimeTemplate,
  type WeeklyTimeRange
} from "@retodo/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import TaskEditModal from "./components/TaskEditModal";
import TaskItem from "./components/TaskItem";
import { API_BASE_URL } from "./config";
import { downloadMarkdown, getOrCreateDeviceId, loadTimeTemplate, parseMarkdownImport, saveTimeTemplate } from "./storage";
import { pullRemoteTasks, pushAndPullTasks } from "./sync";

const HORIZON_OPTIONS = [
  { label: "1 天", days: 1 },
  { label: "7 天", days: 7 },
  { label: "21 天", days: 21 },
  { label: "42 天", days: 42 }
] as const;

const WEEKDAY_OPTIONS = [
  { value: 1, label: "周一" },
  { value: 2, label: "周二" },
  { value: 3, label: "周三" },
  { value: 4, label: "周四" },
  { value: 5, label: "周五" },
  { value: 6, label: "周六" },
  { value: 7, label: "周日" }
] as const;

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

const addDays = (source: Date, days: number): Date => {
  const next = new Date(source);
  next.setDate(next.getDate() + days);
  return next;
};

const formatDay = (source: string): string =>
  new Date(source).toLocaleDateString("zh-CN", { month: "short", day: "numeric", weekday: "short" });

const formatClock = (source: string): string =>
  new Date(source).toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });

const groupBlocksByDay = (blocks: ScheduleBlock[]): Array<{ day: string; blocks: ScheduleBlock[] }> => {
  const grouped = new Map<string, ScheduleBlock[]>();

  for (const block of blocks) {
    const key = block.startAt.slice(0, 10);
    const list = grouped.get(key) ?? [];
    list.push(block);
    grouped.set(key, list);
  }

  return [...grouped.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([day, dayBlocks]) => ({
      day,
      blocks: dayBlocks.sort((a, b) => a.startAt.localeCompare(b.startAt))
    }));
};

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

  const horizonEnd = useMemo(() => addDays(new Date(), horizonDays), [horizonDays]);
  const scheduleView = useMemo(
    () => refreshSchedule(visibleTasks, timeTemplate, new Date(), horizonEnd, createDefaultComparator()),
    [visibleTasks, timeTemplate, horizonEnd]
  );

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

  const blocksByDay = useMemo(() => groupBlocksByDay(scheduleView.blocks), [scheduleView.blocks]);

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
    const parsed = parseQuickInput(quickInput.trim());
    const nextTask = makeTask({
      id: createId(),
      title: parsed.title,
      rawInput: quickInput.trim(),
      estimatedMinutes: parsed.estimatedMinutes,
      minChunkMinutes: parsed.minChunkMinutes,
      dueAt: parsed.dueAt,
      tags: parsed.tags,
      taskTraits: parsed.taskTraits
    });

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
      const parsed = parseQuickInput(line);
      return makeTask({
        id: createId(),
        title: parsed.title,
        rawInput: line,
        estimatedMinutes: parsed.estimatedMinutes,
        minChunkMinutes: parsed.minChunkMinutes,
        dueAt: parsed.dueAt,
        tags: parsed.tags,
        taskTraits: parsed.taskTraits
      });
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
          <div className="template-editor">
            <div className="template-header">
              <div>
                <div className="panel-title">时间模板</div>
                <div className="panel-caption">周模板作为背景容量输入，不直接和调度策略耦合。</div>
              </div>
              <button className="btn-text" onClick={addRange}>
                添加时间段
              </button>
            </div>
            <div className="template-list">
              {timeTemplate.weeklyRanges.map((range) => (
                <div key={range.id} className="template-row">
                  <select
                    className="form-select"
                    value={range.weekday}
                    onChange={(event) => updateRange(range.id, { weekday: Number(event.target.value) as WeeklyTimeRange["weekday"] })}
                  >
                    {WEEKDAY_OPTIONS.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                  <input
                    className="form-input"
                    type="time"
                    value={range.startTime}
                    onChange={(event) => updateRange(range.id, { startTime: event.target.value })}
                  />
                  <input
                    className="form-input"
                    type="time"
                    value={range.endTime}
                    onChange={(event) => updateRange(range.id, { endTime: event.target.value })}
                  />
                  <button className="btn-action danger" onClick={() => removeRange(range.id)}>
                    删除
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}
      </section>

      <section className="card">
        <div className="panel-header">
          <div>
            <div className="panel-title">动态调度视图</div>
            <div className="panel-caption">查看时按当前任务池、时间模板和观察窗口实时重算。</div>
          </div>
          <div className="horizon-tabs">
            {HORIZON_OPTIONS.map((option) => (
              <button
                key={option.days}
                className={`btn-text${horizonDays === option.days ? " active" : ""}`}
                onClick={() => setHorizonDays(option.days)}
              >
                {option.label}
              </button>
            ))}
          </div>
        </div>

        {scheduleView.warnings.length > 0 && (
          <div className="warning-list">
            {scheduleView.warnings.map((warning, index) => (
              <div key={`${warning.code}-${index}`} className={`warning-item ${warning.severity}`}>
                {warning.message}
              </div>
            ))}
          </div>
        )}

        <div className="schedule-grid">
          <div className="schedule-column">
            <div className="subpanel-title">时间块</div>
            {blocksByDay.length === 0 && <div className="empty-panel">当前窗口内还没有排入任何时间块。</div>}
            {blocksByDay.map((group) => (
              <div key={group.day} className="day-group">
                <div className="day-heading">{formatDay(group.blocks[0]?.startAt ?? `${group.day}T00:00:00`)}</div>
                <div className="block-list">
                  {group.blocks.map((block) => {
                    const step = scheduleView.orderedSteps.find((item) => item.stepId === block.stepId);
                    return (
                      <div key={block.id} className="schedule-block">
                        <div className="schedule-block-time">
                          {formatClock(block.startAt)} - {formatClock(block.endAt)}
                        </div>
                        <div className="schedule-block-title">
                          {step?.taskTitle ?? "任务"} / {step?.title ?? "步骤"}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>

          <div className="schedule-column">
            <div className="subpanel-title">任务序列</div>
            <div className="ordered-list">
              {scheduleView.orderedSteps.map((step) => (
                <div key={step.stepId} className={`ordered-item${step.remainingMinutes > 0 ? " unscheduled" : ""}`}>
                  <div className="ordered-title">
                    {step.taskTitle}
                    {step.title !== step.taskTitle && <span className="ordered-step-name"> / {step.title}</span>}
                  </div>
                  <div className="ordered-meta">
                    <span>已排 {step.plannedMinutes}m</span>
                    <span className="task-meta-sep">剩余 {step.remainingMinutes}m</span>
                    {step.dueAt && <span className="task-meta-sep">DDL {step.dueAt.slice(0, 10)}</span>}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="panel-header">
          <div>
            <div className="panel-title">任务池</div>
            <div className="panel-caption">任务、依赖、子步骤都在这里维护。</div>
          </div>
          <div className="search-wrapper compact">
            <span className="search-icon">🔍</span>
            <input
              className="search-input"
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              placeholder="搜索任务"
            />
          </div>
        </div>

        <ul className="task-list">
          {filteredTasks.length === 0 && <li className="empty-state">没有匹配的任务</li>}
          {filteredTasks.map((task) => (
            <TaskItem
              key={task.id}
              task={task}
              onToggleDone={() => toggleDone(task.id)}
              onArchive={() => archiveTask(task.id)}
              onEdit={() => setEditingTask(task)}
            />
          ))}
        </ul>
      </section>

      {editingTask && (
        <TaskEditModal task={editingTask} allTasks={tasks} onSave={saveEditedTask} onClose={() => setEditingTask(null)} />
      )}
    </main>
  );
}

export default App;
