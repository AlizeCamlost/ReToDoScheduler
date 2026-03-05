import type { Task } from "@retodo/core";
import { API_AUTH_TOKEN, API_BASE_URL } from "./config";
import { getOrCreateDeviceId, listTasks, upsertTasks } from "./taskService";

const parseItems = (payload: unknown): Task[] => {
  if (!payload || typeof payload !== "object") return [];
  const data = payload as { items?: unknown };
  if (!Array.isArray(data.items)) return [];
  return data.items as Task[];
};

const normalizeBaseUrl = (input: string): string => {
  const raw = input.trim();
  if (!raw) return "";
  return raw.replace(/\/+$/, "");
};

export const syncTasksWithServer = async (): Promise<{ synced: number }> => {
  const baseUrl = normalizeBaseUrl(API_BASE_URL);
  if (!baseUrl) {
    throw new Error("Missing API_BASE_URL");
  }

  if (!API_AUTH_TOKEN) {
    throw new Error("Missing EXPO_PUBLIC_API_AUTH_TOKEN");
  }

  const [deviceId, localTasks] = await Promise.all([getOrCreateDeviceId(), listTasks()]);

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/v1/tasks/sync`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${API_AUTH_TOKEN}`
      },
      body: JSON.stringify({
        deviceId,
        tasks: localTasks
      })
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`网络连接失败，请检查地址/端口/防火墙。原始错误: ${message}`);
  }

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
