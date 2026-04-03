import type { Task } from "../types";

export type NornTaskBundleKind = "taskSequence";

export interface NornTaskBundleMetadata {
  id: string;
  title?: string | undefined;
  position: number;
  count: number;
  kind: NornTaskBundleKind;
}

const NORN_KEY = "norn";
const TASK_BUNDLE_KEY = "taskBundle";

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === "object" && !Array.isArray(value);

const normalizeText = (value: unknown): string | undefined => {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
};

const normalizeInteger = (value: unknown): number | null => {
  const next = Number(value);
  if (!Number.isInteger(next)) return null;
  return next;
};

const normalizeMetadata = (
  metadata: NornTaskBundleMetadata
): NornTaskBundleMetadata | null => {
  const id = metadata.id.trim();
  const position = normalizeInteger(metadata.position);
  const count = normalizeInteger(metadata.count);
  const title = metadata.title?.trim() || undefined;

  if (!id || position === null || position < 0 || count === null || count <= 0) {
    return null;
  }

  if (metadata.kind !== "taskSequence") {
    return null;
  }

  return {
    id,
    title,
    position,
    count,
    kind: metadata.kind
  };
};

export const parseTaskBundleMetadata = (
  extJson: Record<string, unknown>
): NornTaskBundleMetadata | null => {
  const norn = isRecord(extJson[NORN_KEY]) ? extJson[NORN_KEY] : null;
  const taskBundle = norn && isRecord(norn[TASK_BUNDLE_KEY]) ? norn[TASK_BUNDLE_KEY] : null;

  if (!taskBundle) {
    return null;
  }

  const metadata: NornTaskBundleMetadata = {
    id: typeof taskBundle.id === "string" ? taskBundle.id : "",
    title: normalizeText(taskBundle.title),
    position: Number(taskBundle.position),
    count: Number(taskBundle.count),
    kind: taskBundle.kind === "taskSequence" ? "taskSequence" : ("invalid" as NornTaskBundleKind)
  };

  return normalizeMetadata(metadata);
};

export const getTaskBundleMetadata = (
  task: Pick<Task, "extJson">
): NornTaskBundleMetadata | null => parseTaskBundleMetadata(task.extJson);

export const embedTaskBundleMetadata = (
  extJson: Record<string, unknown>,
  metadata: NornTaskBundleMetadata
): Record<string, unknown> => {
  const normalizedMetadata = normalizeMetadata(metadata);
  if (!normalizedMetadata) {
    return { ...extJson };
  }

  const nextExtJson = { ...extJson };
  const norn =
    isRecord(nextExtJson[NORN_KEY]) ? { ...(nextExtJson[NORN_KEY] as Record<string, unknown>) } : {};

  const taskBundle: Record<string, unknown> = {
    id: normalizedMetadata.id,
    position: normalizedMetadata.position,
    count: normalizedMetadata.count,
    kind: normalizedMetadata.kind
  };

  if (normalizedMetadata.title) {
    taskBundle.title = normalizedMetadata.title;
  }

  norn[TASK_BUNDLE_KEY] = taskBundle;
  nextExtJson[NORN_KEY] = norn;
  return nextExtJson;
};

export const withTaskBundleMetadata = (
  task: Task,
  metadata: NornTaskBundleMetadata
): Task => ({
  ...task,
  extJson: embedTaskBundleMetadata(task.extJson, metadata)
});
