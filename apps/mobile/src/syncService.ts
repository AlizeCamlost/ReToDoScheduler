import type { Task } from "@retodo/core";
import { getOrCreateDeviceId, listTasks, upsertTasks } from "./taskService";

const parseItems = (payload: unknown): Task[] => {
  if (!payload || typeof payload !== "object") return [];
  const data = payload as { items?: unknown };
  if (!Array.isArray(data.items)) return [];
  return data.items as Task[];
};

export const normalizeServerUrl = (input: string): string => {
  const raw = input.trim();
  if (!raw) return "";

  const withScheme = /^https?:\/\//i.test(raw) ? raw : `http://${raw}`;
  try {
    const parsed = new URL(withScheme);
    return parsed.toString().replace(/\/+$/, "");
  } catch {
    throw new Error("服务器地址格式错误，请输入类似 http://1.2.3.4:8787");
  }
};

export const syncTasksWithServer = async (baseUrlInput: string): Promise<{ synced: number }> => {
  const baseUrl = normalizeServerUrl(baseUrlInput);
  if (!baseUrl) {
    throw new Error("Missing server URL");
  }

  const [deviceId, localTasks] = await Promise.all([getOrCreateDeviceId(), listTasks()]);

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/v1/tasks/sync`, {
      method: "POST",
      headers: {
        "content-type": "application/json"
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
