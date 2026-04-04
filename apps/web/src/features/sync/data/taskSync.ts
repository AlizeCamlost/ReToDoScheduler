import {
  makeTask,
  normalizeTaskPoolOrganizationDocument,
  parseTaskPoolOrganizationDocument,
  sortNornTasks,
  type Task,
  type TaskPoolOrganizationDocument
} from "@retodo/core";
import { apiJson } from "../../../shared/network/apiClient";

export interface TaskSyncSnapshot {
  tasks: Task[];
  taskPoolOrganization: TaskPoolOrganizationDocument | null;
}

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

export const mergeTaskPoolOrganizationByLww = (
  local: TaskPoolOrganizationDocument,
  remote: TaskPoolOrganizationDocument | null
): TaskPoolOrganizationDocument => {
  if (!remote) {
    return normalizeTaskPoolOrganizationDocument(local);
  }

  const localTime = new Date(local.updatedAt).getTime();
  const remoteTime = new Date(remote.updatedAt).getTime();
  return normalizeTaskPoolOrganizationDocument(remoteTime >= localTime ? remote : local);
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
        tags: Array.isArray(item.tags) ? item.tags.map((tag) => String(tag)) : [],
        createdAt: String(item.createdAt),
        updatedAt: String(item.updatedAt),
        extJson:
          typeof item.extJson === "object" && item.extJson ? (item.extJson as Record<string, unknown>) : {}
      };

      if (item.scheduleValue && typeof item.scheduleValue === "object") {
        next.scheduleValue = {
          rewardOnTime: Number((item.scheduleValue as Record<string, unknown>).rewardOnTime ?? 10),
          penaltyMissed: Number((item.scheduleValue as Record<string, unknown>).penaltyMissed ?? 25)
        };
      }

      if (Array.isArray(item.dependsOnTaskIds)) {
        next.dependsOnTaskIds = item.dependsOnTaskIds.map((taskId) => String(taskId));
      }

      if (Array.isArray(item.steps)) {
        next.steps = item.steps as Task["steps"];
      }

      if (item.concurrencyMode === "serial") {
        next.concurrencyMode = "serial";
      }

      return makeTask(next);
    });
};

const parseSnapshot = (payload: unknown): TaskSyncSnapshot => {
  if (!payload || typeof payload !== "object") {
    return { tasks: [], taskPoolOrganization: null };
  }

  const data = payload as { taskPoolOrganization?: unknown };
  return {
    tasks: parseItems(payload),
    taskPoolOrganization: parseTaskPoolOrganizationDocument(data.taskPoolOrganization) ?? null
  };
};

export const pullRemoteTasks = async (): Promise<TaskSyncSnapshot> => {
  return parseSnapshot(await apiJson("/v1/tasks"));
};

export const pushAndPullTasks = async (
  tasks: Task[],
  taskPoolOrganization: TaskPoolOrganizationDocument,
  deviceId: string
): Promise<TaskSyncSnapshot> => {
  return parseSnapshot(
    await apiJson("/v1/tasks/sync", {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({
      deviceId,
      tasks,
      taskPoolOrganization
    })
    })
  );
};
