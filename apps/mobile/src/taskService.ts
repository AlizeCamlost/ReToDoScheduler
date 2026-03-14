import { buildQuickTask, embedTaskModel, makeTask, nowIso, type Task } from "@retodo/core";
import { getDb } from "./db";

const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

const rowToTask = (row: Record<string, unknown>): Task =>
  makeTask({
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
    taskTraits: JSON.parse(String(row.task_traits_json)) as Task["taskTraits"],
    tags: JSON.parse(String(row.tags_json)) as string[],
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    extJson: JSON.parse(String(row.ext_json)) as Record<string, unknown>
  });

const upsertTaskSql = `INSERT INTO tasks (
  id, title, raw_input, status, estimated_minutes, min_chunk_minutes, due_at,
  importance, value_score, difficulty, postponability,
  task_traits_json, tags_json, created_at, updated_at, ext_json
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  title = excluded.title,
  raw_input = excluded.raw_input,
  status = excluded.status,
  estimated_minutes = excluded.estimated_minutes,
  min_chunk_minutes = excluded.min_chunk_minutes,
  due_at = excluded.due_at,
  importance = excluded.importance,
  value_score = excluded.value_score,
  difficulty = excluded.difficulty,
  postponability = excluded.postponability,
  task_traits_json = excluded.task_traits_json,
  tags_json = excluded.tags_json,
  updated_at = excluded.updated_at,
  ext_json = excluded.ext_json
WHERE excluded.updated_at > tasks.updated_at`;

export const listTasks = async (): Promise<Task[]> => {
  const db = await getDb();
  const rows = await db.getAllAsync<Record<string, unknown>>(
    `SELECT * FROM tasks
     ORDER BY
       CASE
         WHEN COALESCE(json_extract(ext_json, '$.kairos.rank'), json_extract(ext_json, '$.rank')) IS NULL THEN 1
         ELSE 0
       END ASC,
       CAST(COALESCE(json_extract(ext_json, '$.kairos.rank'), json_extract(ext_json, '$.rank')) AS INTEGER) ASC,
       updated_at DESC`
  );
  return rows.map(rowToTask);
};

export const addTaskFromQuickInput = async (rawInput: string): Promise<void> => {
  const task = buildQuickTask(createId(), rawInput);

  await upsertTasks([task]);
};

export const upsertTasks = async (tasks: Task[]): Promise<void> => {
  if (tasks.length === 0) return;

  const db = await getDb();
  await db.withTransactionAsync(async () => {
    for (const task of tasks) {
      await db.runAsync(
        upsertTaskSql,
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
        JSON.stringify(embedTaskModel(task))
      );
    }
  });
};

export const toggleTaskDone = async (task: Task): Promise<void> => {
  const db = await getDb();
  const nextStatus = task.status === "done" ? "todo" : "done";
  await db.runAsync("UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?", nextStatus, nowIso(), task.id);
};

export const archiveTask = async (taskId: string): Promise<void> => {
  const db = await getDb();
  await db.runAsync("UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?", "archived", nowIso(), taskId);
};

export const getSetting = async (key: string): Promise<string | null> => {
  const db = await getDb();
  const row = await db.getFirstAsync<{ value: string }>("SELECT value FROM settings WHERE key = ?", key);
  return row?.value ?? null;
};

export const setSetting = async (key: string, value: string): Promise<void> => {
  const db = await getDb();
  await db.runAsync(
    `INSERT INTO settings (key, value) VALUES (?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
    key,
    value
  );
};

export const getOrCreateDeviceId = async (): Promise<string> => {
  const existing = await getSetting("device_id");
  if (existing) return existing;

  const id = createId();
  await setSetting("device_id", id);
  return id;
};
