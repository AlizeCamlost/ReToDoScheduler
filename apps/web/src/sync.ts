import type { Task } from "@retodo/core";

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

  return [...merged.values()].sort((a, b) =>
    new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
  );
};

const parseItems = (payload: unknown): Task[] => {
  if (!payload || typeof payload !== "object") return [];
  const data = payload as { items?: unknown };
  if (!Array.isArray(data.items)) return [];
  return data.items as Task[];
};

export const pullRemoteTasks = async (baseUrl: string): Promise<Task[]> => {
  const response = await fetch(buildUrl(baseUrl, "/v1/tasks"));
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
  const response = await fetch(buildUrl(baseUrl, "/v1/tasks/sync"), {
    method: "POST",
    headers: {
      "content-type": "application/json"
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
