import type { Task } from "@retodo/core";
import { getOrCreateDeviceId, listTasks, upsertTasks } from "./taskService";

const parseItems = (payload: unknown): Task[] => {
  if (!payload || typeof payload !== "object") return [];
  const data = payload as { items?: unknown };
  if (!Array.isArray(data.items)) return [];
  return data.items as Task[];
};

const normalizeBaseUrl = (url: string): string => url.trim().replace(/\/+$/, "");

export const syncTasksWithServer = async (baseUrlInput: string): Promise<{ synced: number }> => {
  const baseUrl = normalizeBaseUrl(baseUrlInput);
  if (!baseUrl) {
    throw new Error("Missing server URL");
  }

  const [deviceId, localTasks] = await Promise.all([getOrCreateDeviceId(), listTasks()]);

  const response = await fetch(`${baseUrl}/v1/tasks/sync`, {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({
      deviceId,
      tasks: localTasks
    })
  });

  if (!response.ok) {
    throw new Error(`Sync failed (${response.status})`);
  }

  const payload = (await response.json()) as { synced?: number; items?: unknown };
  const remoteTasks = parseItems(payload);
  await upsertTasks(remoteTasks);

  return {
    synced: Number(payload.synced ?? localTasks.length)
  };
};
