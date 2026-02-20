import { makeTask, nowIso, parseQuickInput, type Task } from "@retodo/core";
import { getDb } from "./db";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

const rowToTask = (row: Record<string, unknown>): Task => ({
  id: String(row.id),
  title: String(row.title),
  rawInput: String(row.raw_input),
  status: row.status as Task["status"],
  estimatedMinutes: Number(row.estimated_minutes),
  minChunkMinutes: Number(row.min_chunk_minutes),
  dueAt: row.due_at ? String(row.due_at) : undefined,
  importance: Number(row.importance),
  value: Number(row.value_score),
  difficulty: Number(row.difficulty),
  postponability: Number(row.postponability),
  taskTraits: JSON.parse(String(row.task_traits_json)),
  tags: JSON.parse(String(row.tags_json)),
  createdAt: String(row.created_at),
  updatedAt: String(row.updated_at),
  extJson: JSON.parse(String(row.ext_json))
});

export const listTasks = async (): Promise<Task[]> => {
  const db = await getDb();
  const rows = await db.getAllAsync<Record<string, unknown>>("SELECT * FROM tasks ORDER BY updated_at DESC");
  return rows.map(rowToTask);
};

export const addTaskFromQuickInput = async (rawInput: string): Promise<void> => {
  const parsed = parseQuickInput(rawInput);
  const task = makeTask({
    id: createId(),
    title: parsed.title,
    rawInput,
    estimatedMinutes: parsed.estimatedMinutes,
    minChunkMinutes: parsed.minChunkMinutes,
    dueAt: parsed.dueAt,
    tags: parsed.tags,
    taskTraits: parsed.taskTraits
  });

  const db = await getDb();
  await db.runAsync(
    `INSERT INTO tasks (
      id, title, raw_input, status, estimated_minutes, min_chunk_minutes, due_at,
      importance, value_score, difficulty, postponability,
      task_traits_json, tags_json, created_at, updated_at, ext_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    task.id,
    task.title,
    task.rawInput,
    task.status,
    task.estimatedMinutes,
    task.minChunkMinutes,
    task.dueAt ?? null,
    task.importance,
    task.value,
    task.difficulty,
    task.postponability,
    JSON.stringify(task.taskTraits),
    JSON.stringify(task.tags),
    task.createdAt,
    task.updatedAt,
    JSON.stringify(task.extJson)
  );
};

export const toggleTaskDone = async (task: Task): Promise<void> => {
  const db = await getDb();
  const nextStatus = task.status === "done" ? "todo" : "done";
  await db.runAsync("UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?", nextStatus, nowIso(), task.id);
};

export const deleteTask = async (taskId: string): Promise<void> => {
  const db = await getDb();
  await db.runAsync("DELETE FROM tasks WHERE id = ?", taskId);
};
