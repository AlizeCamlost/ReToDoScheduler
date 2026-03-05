import type { Task } from "../types";

export interface KairosDecisionCursor {
  rank?: number;
  strategy?: string;
  updatedAt?: string;
}

const readExt = (task: Task): Record<string, unknown> =>
  typeof task.extJson === "object" && task.extJson ? task.extJson : {};

export const getKairosCursor = (task: Task): KairosDecisionCursor => {
  const ext = readExt(task);
  const kairos = ext.kairos;

  if (kairos && typeof kairos === "object") {
    const obj = kairos as Record<string, unknown>;
    const cursor: KairosDecisionCursor = {};
    if (typeof obj.rank === "number") cursor.rank = obj.rank;
    if (typeof obj.strategy === "string") cursor.strategy = obj.strategy;
    if (typeof obj.updatedAt === "string") cursor.updatedAt = obj.updatedAt;
    return cursor;
  }

  // Backward compatibility for older payloads that stored rank at extJson.rank.
  const legacyCursor: KairosDecisionCursor = {};
  if (typeof ext.rank === "number") legacyCursor.rank = ext.rank;
  return legacyCursor;
};

export const withKairosRank = (task: Task, rank: number): Task => {
  const ext = readExt(task);
  const legacy = typeof ext.rank === "number" ? { rank } : {};
  return {
    ...task,
    extJson: {
      ...ext,
      ...legacy,
      kairos: {
        ...(typeof ext.kairos === "object" && ext.kairos ? (ext.kairos as Record<string, unknown>) : {}),
        rank,
        strategy: "manual-drag",
        updatedAt: new Date().toISOString()
      }
    }
  };
};

export const getKairosRank = (task: Task): number | null => {
  const cursor = getKairosCursor(task);
  return typeof cursor.rank === "number" ? cursor.rank : null;
};
