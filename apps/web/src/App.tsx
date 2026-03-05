import { makeTask, nowIso, parseQuickInput, type Task } from "@retodo/core";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  downloadMarkdown,
  getOrCreateDeviceId,
  loadApiBaseUrl,
  parseMarkdownImport
} from "./storage";
import { pullRemoteTasks, pushAndPullTasks } from "./sync";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

const sortByUpdatedAt = (items: Task[]): Task[] =>
  [...items].sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());

function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [quickInput, setQuickInput] = useState("");
  const [showDetails, setShowDetails] = useState(false);
  const [manualMinChunk, setManualMinChunk] = useState<string>("");
  const [manualEstimate, setManualEstimate] = useState<string>("");
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [apiBaseUrl, setApiBaseUrl] = useState<string>(() => loadApiBaseUrl());
  const [syncMessage, setSyncMessage] = useState("未同步");
  const [isSyncing, setIsSyncing] = useState(false);

  const tasksRef = useRef(tasks);
  const deviceIdRef = useRef(getOrCreateDeviceId());
  const syncInFlightRef = useRef(false);

  useEffect(() => {
    tasksRef.current = tasks;
  }, [tasks]);

  const visibleTasks = useMemo(() => tasks.filter((task) => task.status !== "archived"), [tasks]);

  const todoCount = useMemo(
    () => visibleTasks.filter((task) => task.status !== "done").length,
    [visibleTasks]
  );

  const applyRemoteTasks = (incoming: Task[]) => {
    const sorted = sortByUpdatedAt(incoming);
    setTasks(sorted);
    tasksRef.current = sorted;
  };

  const performSync = async (tasksToPush?: Task[]) => {
    const baseUrl = apiBaseUrl.trim();
    if (!baseUrl || syncInFlightRef.current) return;

    syncInFlightRef.current = true;
    setIsSyncing(true);

    try {
      const remote = await pushAndPullTasks(baseUrl, deviceIdRef.current, tasksToPush ?? tasksRef.current);
      applyRemoteTasks(remote);
      setSyncMessage(`已同步 ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setSyncMessage(`同步失败: ${message}`);
    } finally {
      syncInFlightRef.current = false;
      setIsSyncing(false);
    }
  };

  const pullOnly = async () => {
    const baseUrl = apiBaseUrl.trim();
    if (!baseUrl || syncInFlightRef.current) return;

    try {
      const remote = await pullRemoteTasks(baseUrl);
      applyRemoteTasks(remote);
      setSyncMessage(`已拉取 ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setSyncMessage(`拉取失败: ${message}`);
    }
  };

  const commitTasks = (next: Task[]) => {
    setTasks(next);
    tasksRef.current = next;
    void performSync(next);
  };

  useEffect(() => {
    void pullOnly();
  }, [apiBaseUrl]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      void pullOnly();
    }, 7000);

    return () => {
      window.clearInterval(timer);
    };
  }, [apiBaseUrl]);

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
      tasks.map((task) =>
        task.id === taskId
          ? {
              ...task,
              status: task.status === "done" ? "todo" : "done",
              updatedAt: nowIso()
            }
          : task
      )
    );
  };

  const archiveTask = (taskId: string) => {
    commitTasks(
      tasks.map((task) =>
        task.id === taskId
          ? {
              ...task,
              status: "archived",
              updatedAt: nowIso()
            }
          : task
      )
    );
  };

  const reorder = (sourceId: string, targetId: string) => {
    if (sourceId === targetId) return;
    const sourceIndex = visibleTasks.findIndex((task) => task.id === sourceId);
    const targetIndex = visibleTasks.findIndex((task) => task.id === targetId);
    if (sourceIndex < 0 || targetIndex < 0) return;

    const visible = [...visibleTasks];
    const [moved] = visible.splice(sourceIndex, 1);
    if (!moved) return;
    visible.splice(targetIndex, 0, moved);

    const visibleIds = new Set(visible.map((task) => task.id));
    const hidden = tasks.filter((task) => !visibleIds.has(task.id));
    const reordered = [...visible, ...hidden].map((task, idx) => ({
      ...task,
      extJson: { ...task.extJson, rank: idx },
      updatedAt: nowIso()
    }));

    commitTasks(reordered);
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
        minChunkMinutes: parsed.minChunkMinutes,
        estimatedMinutes: parsed.estimatedMinutes,
        dueAt: parsed.dueAt,
        tags: parsed.tags,
        taskTraits: parsed.taskTraits
      });
    });

    commitTasks([...imported, ...tasks]);
  };

  return (
    <main className="app">
      <section className="panel">
        <h1>ReToDoScheduler</h1>
        <p className="muted">任务未完成：{todoCount}（Web 端不做本地持久化，数据以服务器为准）</p>
        <div className="row">
          <input
            type="text"
            value={apiBaseUrl}
            onChange={(event) => setApiBaseUrl(event.target.value)}
            placeholder="服务器地址，例如：http://1.2.3.4:8787"
          />
          <button onClick={() => void performSync()} disabled={isSyncing}>
            {isSyncing ? "同步中" : "立即同步"}
          </button>
        </div>
        <p className="muted">{syncMessage}</p>
        <div className="row">
          <input
            type="text"
            value={quickInput}
            onChange={(event) => setQuickInput(event.target.value)}
            placeholder="输入任务，例如：明天前完成周报 90分钟 #工作 专注"
          />
          <button onClick={addTask}>添加</button>
        </div>
        <div className="row" style={{ marginTop: 8 }}>
          <button onClick={() => setShowDetails((value) => !value)}>
            {showDetails ? "收起详情" : "展开详情"}
          </button>
          <button onClick={() => downloadMarkdown(tasks)}>导出 Markdown</button>
          <label>
            导入 Markdown
            <input
              type="file"
              accept=".md,text/markdown"
              onChange={(event) => void importMarkdown(event.target.files?.[0] ?? null)}
            />
          </label>
        </div>
        {showDetails ? (
          <div className="row" style={{ marginTop: 8 }}>
            <input
              type="text"
              placeholder="估时（分钟，可选）"
              value={manualEstimate}
              onChange={(event) => setManualEstimate(event.target.value)}
            />
            <input
              type="text"
              placeholder="最小拆分（分钟，可选）"
              value={manualMinChunk}
              onChange={(event) => setManualMinChunk(event.target.value)}
            />
          </div>
        ) : null}
      </section>

      <section className="panel">
        <h2>任务</h2>
        <p className="muted">拖拽重排后会自动同步到服务器（LWW）。</p>
        <ul className="task-list">
          {visibleTasks.map((task) => (
            <li
              key={task.id}
              className="task-item"
              draggable
              onDragStart={() => setDraggingId(task.id)}
              onDragOver={(event) => event.preventDefault()}
              onDrop={() => {
                if (!draggingId) return;
                reorder(draggingId, task.id);
                setDraggingId(null);
              }}
            >
              <div className="task-top">
                <div>
                  <div className={`task-title ${task.status === "done" ? "done" : ""}`}>{task.title}</div>
                  <div className="muted">
                    估时 {task.estimatedMinutes}m | 最小拆分 {task.minChunkMinutes}m
                    {task.dueAt ? ` | 截止 ${task.dueAt.slice(0, 10)}` : ""}
                  </div>
                  <div>
                    {task.tags.map((tag) => (
                      <span key={tag} className="badge">
                        #{tag}
                      </span>
                    ))}
                  </div>
                </div>
                <div className="actions">
                  <button onClick={() => toggleDone(task.id)}>{task.status === "done" ? "撤销" : "完成"}</button>
                  <button onClick={() => archiveTask(task.id)}>删除</button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}

export default App;
