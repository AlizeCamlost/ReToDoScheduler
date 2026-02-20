import { makeTask, nowIso, parseQuickInput, type Task } from "@retodo/core";
import { useMemo, useState } from "react";
import { downloadMarkdown, loadTasks, parseMarkdownImport, saveTasks } from "./storage";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

function App() {
  const [tasks, setTasks] = useState<Task[]>(() => loadTasks());
  const [quickInput, setQuickInput] = useState("");
  const [showDetails, setShowDetails] = useState(false);
  const [manualMinChunk, setManualMinChunk] = useState<string>("");
  const [manualEstimate, setManualEstimate] = useState<string>("");
  const [draggingId, setDraggingId] = useState<string | null>(null);

  const todoCount = useMemo(() => tasks.filter((task) => task.status !== "done").length, [tasks]);

  const commitTasks = (next: Task[]) => {
    setTasks(next);
    saveTasks(next);
  };

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

  const removeTask = (taskId: string) => {
    commitTasks(tasks.filter((task) => task.id !== taskId));
  };

  const reorder = (sourceId: string, targetId: string) => {
    if (sourceId === targetId) return;
    const sourceIndex = tasks.findIndex((task) => task.id === sourceId);
    const targetIndex = tasks.findIndex((task) => task.id === targetId);
    if (sourceIndex < 0 || targetIndex < 0) return;

    const next = [...tasks];
    const [moved] = next.splice(sourceIndex, 1);
    if (!moved) return;
    next.splice(targetIndex, 0, moved);

    commitTasks(
      next.map((task, idx) => ({
        ...task,
        extJson: { ...task.extJson, rank: idx },
        updatedAt: nowIso()
      }))
    );
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
        <p className="muted">离线优先任务列表（MVP）。未完成：{todoCount}</p>
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
        <p className="muted">支持拖拽重排，当前重排会写入本地 rank（学习样本占位）。</p>
        <ul className="task-list">
          {tasks.map((task) => (
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
                  <button onClick={() => removeTask(task.id)}>删除</button>
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
