import { makeTask, nowIso, parseQuickInput, sortNornTasks, type Task, withKairosRank } from "@retodo/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import TaskEditModal from "./components/TaskEditModal";
import TaskItem from "./components/TaskItem";
import { API_BASE_URL } from "./config";
import { downloadMarkdown, getOrCreateDeviceId, parseMarkdownImport } from "./storage";
import { pullRemoteTasks, pushAndPullTasks } from "./sync";

type StatusFilter = "all" | "todo" | "done";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [quickInput, setQuickInput] = useState("");
  const [showDetails, setShowDetails] = useState(false);
  const [manualMinChunk, setManualMinChunk] = useState("");
  const [manualEstimate, setManualEstimate] = useState("");
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [syncMessage, setSyncMessage] = useState("未同步");
  const [isSyncing, setIsSyncing] = useState(false);
  const [editingTask, setEditingTask] = useState<Task | null>(null);

  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [activeTag, setActiveTag] = useState<string | null>(null);

  const tasksRef = useRef(tasks);
  const deviceIdRef = useRef(getOrCreateDeviceId());
  const syncInFlightRef = useRef(false);

  useEffect(() => {
    tasksRef.current = tasks;
  }, [tasks]);

  // ── Derived data ──

  const visibleTasks = useMemo(() => tasks.filter((t) => t.status !== "archived"), [tasks]);

  const allTags = useMemo(() => {
    const set = new Set<string>();
    for (const t of visibleTasks) {
      for (const tag of t.tags) set.add(tag);
    }
    return [...set].sort();
  }, [visibleTasks]);

  const filteredTasks = useMemo(() => {
    let result = visibleTasks;

    if (statusFilter === "todo") {
      result = result.filter((t) => t.status !== "done");
    } else if (statusFilter === "done") {
      result = result.filter((t) => t.status === "done");
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        (t) =>
          t.title.toLowerCase().includes(q) ||
          t.tags.some((tag) => tag.toLowerCase().includes(q)) ||
          (t.description ?? "").toLowerCase().includes(q)
      );
    }

    if (activeTag) {
      result = result.filter((t) => t.tags.includes(activeTag));
    }

    return result;
  }, [visibleTasks, statusFilter, searchQuery, activeTag]);

  const todoCount = useMemo(() => visibleTasks.filter((t) => t.status !== "done").length, [visibleTasks]);

  const syncStatus = syncMessage.startsWith("同步失败") || syncMessage.startsWith("拉取失败") ? "error" : isSyncing ? "syncing" : "ok";

  // ── Sync ──

  const applyRemoteTasks = useCallback((incoming: Task[]) => {
    const sorted = sortNornTasks(incoming);
    setTasks(sorted);
    tasksRef.current = sorted;
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

  // ── Task actions ──

  const addTask = () => {
    if (!quickInput.trim()) return;
    const parsed = parseQuickInput(quickInput);
    const minChunk = manualMinChunk ? Number(manualMinChunk) : parsed.minChunkMinutes;
    const estimate = manualEstimate ? Number(manualEstimate) : parsed.estimatedMinutes;

    const nextTask = makeTask({
      id: createId(),
      title: parsed.title,
      rawInput: quickInput,
      minChunkMinutes: Number.isFinite(minChunk) ? minChunk : parsed.minChunkMinutes,
      estimatedMinutes: Number.isFinite(estimate) ? estimate : parsed.estimatedMinutes,
      dueAt: parsed.dueAt,
      tags: parsed.tags,
      taskTraits: parsed.taskTraits
    });

    commitTasks([nextTask, ...tasks]);
    setQuickInput("");
    setManualMinChunk("");
    setManualEstimate("");
  };

  const toggleDone = (taskId: string) => {
    commitTasks(
      tasks.map((t) =>
        t.id === taskId ? { ...t, status: t.status === "done" ? ("todo" as const) : ("done" as const), updatedAt: nowIso() } : t
      )
    );
  };

  const archiveTask = (taskId: string) => {
    commitTasks(tasks.map((t) => (t.id === taskId ? { ...t, status: "archived" as const, updatedAt: nowIso() } : t)));
  };

  const saveEditedTask = (updated: Task) => {
    commitTasks(tasks.map((t) => (t.id === updated.id ? updated : t)));
    setEditingTask(null);
  };

  const reorder = (sourceId: string, targetId: string) => {
    if (sourceId === targetId) return;
    const sourceIndex = visibleTasks.findIndex((t) => t.id === sourceId);
    const targetIndex = visibleTasks.findIndex((t) => t.id === targetId);
    if (sourceIndex < 0 || targetIndex < 0) return;

    const visible = [...visibleTasks];
    const [moved] = visible.splice(sourceIndex, 1);
    if (!moved) return;
    visible.splice(targetIndex, 0, moved);

    const visibleIds = new Set(visible.map((t) => t.id));
    const hidden = tasks.filter((t) => !visibleIds.has(t.id));
    const reordered = [...visible, ...hidden].map((t, idx) => ({
      ...withKairosRank(t, idx),
      updatedAt: nowIso()
    }));

    commitTasks(reordered);
  };

  const importMarkdown = async (file: File | null) => {
    if (!file) return;
    const text = await file.text();
    const lines = parseMarkdownImport(text);
    if (lines.length === 0) return;

    const imported = lines.map((line, idx) => {
      const parsed = parseQuickInput(line);
      return withKairosRank(
        makeTask({
          id: createId(),
          title: parsed.title,
          rawInput: line,
          minChunkMinutes: parsed.minChunkMinutes,
          estimatedMinutes: parsed.estimatedMinutes,
          dueAt: parsed.dueAt,
          tags: parsed.tags,
          taskTraits: parsed.taskTraits
        }),
        idx
      );
    });

    commitTasks([...imported, ...tasks]);
  };

  const handleInputKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      addTask();
    }
  };

  // ── Render ──

  return (
    <main className="app">
      {/* Header */}
      <header className="header">
        <div className="header-left">
          <h1>Norn</h1>
          <span className="task-count">{todoCount} 项待办</span>
        </div>
        <div className="sync-area">
          <div className="sync-indicator">
            <span className={`sync-dot ${syncStatus}`} />
            <span className="sync-text">{syncMessage}</span>
          </div>
          <button
            className="btn-icon"
            onClick={() => void performSync()}
            disabled={isSyncing}
            title="立即同步"
          >
            {isSyncing ? "..." : "\u21BB"}
          </button>
        </div>
      </header>

      {/* Quick input */}
      <section className="card">
        <div className="input-area">
          <input
            className="input-main"
            type="text"
            value={quickInput}
            onChange={(e) => setQuickInput(e.target.value)}
            onKeyDown={handleInputKeyDown}
            placeholder="输入任务，如：明天前完成周报 90分钟 #工作 专注"
          />
          <button className="btn-add" onClick={addTask}>
            添加
          </button>
        </div>

        <div className="toolbar">
          <button className={`btn-text${showDetails ? " active" : ""}`} onClick={() => setShowDetails((v) => !v)}>
            {showDetails ? "收起详情" : "详情"}
          </button>
          <button className="btn-text" onClick={() => downloadMarkdown(tasks)}>
            导出
          </button>
          <label className="file-label">
            导入
            <input type="file" accept=".md,text/markdown" onChange={(e) => void importMarkdown(e.target.files?.[0] ?? null)} />
          </label>
        </div>

        {showDetails && (
          <div className="detail-row">
            <input
              className="detail-input"
              type="text"
              placeholder="预估时长（分钟）"
              value={manualEstimate}
              onChange={(e) => setManualEstimate(e.target.value)}
            />
            <input
              className="detail-input"
              type="text"
              placeholder="最小拆分（分钟）"
              value={manualMinChunk}
              onChange={(e) => setManualMinChunk(e.target.value)}
            />
          </div>
        )}
      </section>

      {/* Filter bar */}
      <div className="filter-bar">
        <div className="filter-tabs">
          {(["all", "todo", "done"] as const).map((f) => (
            <button
              key={f}
              className={`filter-tab${statusFilter === f ? " active" : ""}`}
              onClick={() => setStatusFilter(f)}
            >
              {{ all: "全部", todo: "待办", done: "已完成" }[f]}
            </button>
          ))}
        </div>
        <div className="search-wrapper">
          <span className="search-icon">{"\u{1F50D}"}</span>
          <input
            className="search-input"
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="搜索任务..."
          />
        </div>
      </div>

      {/* Tag filter */}
      {allTags.length > 0 && (
        <div className="tag-filter-bar">
          {activeTag && (
            <button className="badge-filter active" onClick={() => setActiveTag(null)}>
              全部
            </button>
          )}
          {allTags.map((tag) => (
            <button
              key={tag}
              className={`badge-filter${activeTag === tag ? " active" : ""}`}
              onClick={() => setActiveTag(activeTag === tag ? null : tag)}
            >
              #{tag}
            </button>
          ))}
        </div>
      )}

      {/* Task list */}
      <ul className="task-list">
        {filteredTasks.length === 0 && (
          <li className="empty-state">
            {visibleTasks.length === 0 ? "还没有任务，在上方输入框添加第一个任务" : "没有匹配的任务"}
          </li>
        )}
        {filteredTasks.map((task) => (
          <TaskItem
            key={task.id}
            task={task}
            isDragging={draggingId === task.id}
            onToggleDone={() => toggleDone(task.id)}
            onArchive={() => archiveTask(task.id)}
            onEdit={() => setEditingTask(task)}
            onDragStart={() => setDraggingId(task.id)}
            onDragOver={(e) => e.preventDefault()}
            onDrop={() => {
              if (draggingId) {
                reorder(draggingId, task.id);
                setDraggingId(null);
              }
            }}
          />
        ))}
      </ul>

      {/* Edit modal */}
      {editingTask && <TaskEditModal task={editingTask} onSave={saveEditedTask} onClose={() => setEditingTask(null)} />}
    </main>
  );
}

export default App;
