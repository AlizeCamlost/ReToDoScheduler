import type { FastifyPluginAsync } from "fastify";
import { pool } from "../db.js";

type TaskStatus = "todo" | "doing" | "done" | "archived";

interface SyncTaskPayload {
  id: string;
  title: string;
  rawInput: string;
  description?: string | undefined;
  status: TaskStatus;
  estimatedMinutes: number;
  minChunkMinutes: number;
  dueAt?: string | undefined;
  importance: number;
  value: number;
  difficulty: number;
  postponability: number;
  taskTraits: Record<string, unknown>;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  extJson: Record<string, unknown>;
}

interface SyncBody {
  deviceId: string;
  tasks: SyncTaskPayload[];
}

const coerceTask = (value: unknown): SyncTaskPayload | null => {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;

  if (typeof item.id !== "string" || typeof item.title !== "string" || typeof item.rawInput !== "string") {
    return null;
  }

  if (typeof item.createdAt !== "string" || typeof item.updatedAt !== "string") return null;

  return {
    id: item.id,
    title: item.title,
    rawInput: item.rawInput,
    description: typeof item.description === "string" ? item.description : undefined,
    status: (item.status as TaskStatus) ?? "todo",
    estimatedMinutes: Number(item.estimatedMinutes ?? 30),
    minChunkMinutes: Number(item.minChunkMinutes ?? 25),
    dueAt: typeof item.dueAt === "string" ? item.dueAt : undefined,
    importance: Number(item.importance ?? 3),
    value: Number(item.value ?? 3),
    difficulty: Number(item.difficulty ?? 3),
    postponability: Number(item.postponability ?? 3),
    taskTraits: typeof item.taskTraits === "object" && item.taskTraits ? (item.taskTraits as Record<string, unknown>) : {},
    tags: Array.isArray(item.tags) ? item.tags.map((tag) => String(tag)) : [],
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    extJson: typeof item.extJson === "object" && item.extJson ? (item.extJson as Record<string, unknown>) : {}
  };
};

const rowToTask = (row: Record<string, unknown>): SyncTaskPayload => ({
  id: String(row.id),
  title: String(row.title),
  rawInput: String(row.raw_input),
  description: row.description ? String(row.description) : undefined,
  status: String(row.status) as TaskStatus,
  estimatedMinutes: Number(row.estimated_minutes),
  minChunkMinutes: Number(row.min_chunk_minutes),
  dueAt: row.due_at ? new Date(String(row.due_at)).toISOString() : undefined,
  importance: Number(row.importance),
  value: Number(row.value_score),
  difficulty: Number(row.difficulty),
  postponability: Number(row.postponability),
  taskTraits: row.task_traits_json as Record<string, unknown>,
  tags: Array.isArray(row.tags_json) ? (row.tags_json as string[]) : [],
  createdAt: new Date(String(row.created_at)).toISOString(),
  updatedAt: new Date(String(row.updated_at)).toISOString(),
  extJson: (row.ext_json as Record<string, unknown>) ?? {}
});

const fetchAllTasks = async (): Promise<SyncTaskPayload[]> => {
  const result = await pool.query<Record<string, unknown>>(
    "SELECT * FROM tasks ORDER BY COALESCE((ext_json->>'rank')::int, 2147483647) ASC, updated_at DESC"
  );
  return result.rows.map(rowToTask);
};

const upsertOneTask = async (task: SyncTaskPayload): Promise<void> => {
  await pool.query(
    `INSERT INTO tasks (
      id, title, raw_input, description, status,
      estimated_minutes, min_chunk_minutes, due_at,
      importance, value_score, difficulty, postponability,
      task_traits_json, tags_json, ext_json,
      created_at, updated_at
    ) VALUES (
      $1, $2, $3, $4, $5,
      $6, $7, $8,
      $9, $10, $11, $12,
      $13::jsonb, $14::jsonb, $15::jsonb,
      $16::timestamptz, $17::timestamptz
    )
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      raw_input = EXCLUDED.raw_input,
      description = EXCLUDED.description,
      status = EXCLUDED.status,
      estimated_minutes = EXCLUDED.estimated_minutes,
      min_chunk_minutes = EXCLUDED.min_chunk_minutes,
      due_at = EXCLUDED.due_at,
      importance = EXCLUDED.importance,
      value_score = EXCLUDED.value_score,
      difficulty = EXCLUDED.difficulty,
      postponability = EXCLUDED.postponability,
      task_traits_json = EXCLUDED.task_traits_json,
      tags_json = EXCLUDED.tags_json,
      ext_json = EXCLUDED.ext_json,
      updated_at = EXCLUDED.updated_at
    WHERE EXCLUDED.updated_at > tasks.updated_at`,
    [
      task.id,
      task.title,
      task.rawInput,
      task.description ?? null,
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
      JSON.stringify(task.extJson),
      task.createdAt,
      task.updatedAt
    ]
  );
};

const taskRoutes: FastifyPluginAsync = async (app) => {
  const requiredToken = process.env.API_AUTH_TOKEN;
  if (!requiredToken) {
    throw new Error("Missing API_AUTH_TOKEN");
  }

  app.addHook("onRequest", async (request, reply) => {
    const header = request.headers.authorization;
    if (!header || !header.startsWith("Bearer ")) {
      reply.code(401);
      return reply.send({ error: "Unauthorized" });
    }

    const token = header.slice("Bearer ".length).trim();
    if (token !== requiredToken) {
      reply.code(401);
      return reply.send({ error: "Unauthorized" });
    }
  });

  app.get("/v1/tasks", async () => {
    const items = await fetchAllTasks();
    return { items };
  });

  app.post<{ Body: SyncBody }>("/v1/tasks/sync", async (request, reply) => {
    const body = request.body;
    if (!body || typeof body.deviceId !== "string" || !Array.isArray(body.tasks)) {
      reply.code(400);
      return { error: "Invalid sync payload" };
    }

    const normalized = body.tasks
      .map(coerceTask)
      .filter((item): item is SyncTaskPayload => item !== null);

    for (const task of normalized) {
      await upsertOneTask(task);
    }

    const items = await fetchAllTasks();
    return {
      deviceId: body.deviceId,
      synced: normalized.length,
      items
    };
  });
};

export default taskRoutes;
