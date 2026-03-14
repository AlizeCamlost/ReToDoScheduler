import { makeTask, sortNornTasks, type Task } from "@retodo/core";
import { API_AUTH_TOKEN } from "./config";

const buildUrl = (baseUrl: string, path: string): string => {
  const normalized = baseUrl.trim().replace(/\/+$/, "");
  return `${normalized}${path}`;
};

export const mergeByLww = (localTasks: Task[], remoteTasks: Task[]): Task[] => {
  const merged = new Map<string, Task>();

  for (const task of localTasks) {
    merged.set(task.id, task);
  }

  for (const remote of remoteTasks) {
    const current = merged.get(remote.id);
    if (!current) {
      merged.set(remote.id, remote);
      continue;
    }

    const remoteTime = new Date(remote.updatedAt).getTime();
    const currentTime = new Date(current.updatedAt).getTime();
    if (remoteTime >= currentTime) {
      merged.set(remote.id, remote);
    }
  }

  return sortNornTasks([...merged.values()]);
};

const parseItems = (payload: unknown): Task[] => {
  if (!payload || typeof payload !== "object") return [];
  const data = payload as { items?: unknown };
  if (!Array.isArray(data.items)) return [];
  return data.items
    .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
    .map((item) => {
      const next: Parameters<typeof makeTask>[0] = {
        id: String(item.id),
        title: String(item.title),
        rawInput: String(item.rawInput),
        description: typeof item.description === "string" ? item.description : undefined,
        status: (item.status as Task["status"]) ?? "todo",
        estimatedMinutes: Number(item.estimatedMinutes),
        minChunkMinutes: Number(item.minChunkMinutes),
        dueAt: typeof item.dueAt === "string" ? item.dueAt : undefined,
        importance: Number(item.importance),
        value: Number(item.value),
        difficulty: Number(item.difficulty),
        postponability: Number(item.postponability),
        tags: Array.isArray(item.tags) ? item.tags.map((tag) => String(tag)) : [],
        createdAt: String(item.createdAt),
        updatedAt: String(item.updatedAt),
        extJson:
          typeof item.extJson === "object" && item.extJson ? (item.extJson as Record<string, unknown>) : {}
      };

      if (typeof item.taskTraits === "object" && item.taskTraits) {
        next.taskTraits = item.taskTraits as Task["taskTraits"];
      }

      return makeTask(next);
    });
};

export const pullRemoteTasks = async (baseUrl: string): Promise<Task[]> => {
  if (!API_AUTH_TOKEN) {
    throw new Error("Missing VITE_API_AUTH_TOKEN");
  }
  const response = await fetch(buildUrl(baseUrl, "/v1/tasks"), {
    headers: {
      authorization: `Bearer ${API_AUTH_TOKEN}`
    }
  });
  if (!response.ok) {
    throw new Error(`Pull failed (${response.status})`);
  }
  return parseItems(await response.json());
};

export const pushAndPullTasks = async (
  baseUrl: string,
  deviceId: string,
  tasks: Task[]
): Promise<Task[]> => {
  if (!API_AUTH_TOKEN) {
    throw new Error("Missing VITE_API_AUTH_TOKEN");
  }
  const response = await fetch(buildUrl(baseUrl, "/v1/tasks/sync"), {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${API_AUTH_TOKEN}`
    },
    body: JSON.stringify({
      deviceId,
      tasks
    })
  });

  if (!response.ok) {
    throw new Error(`Sync failed (${response.status})`);
  }

  return parseItems(await response.json());
};
