import { nowIso } from "../defaults";
import type {
  TaskPoolCanvasNodeLayout,
  TaskPoolDirectory,
  TaskPoolOrganizationDocument,
  TaskPoolTaskPlacement
} from "../types";

export const TASK_POOL_ORGANIZATION_VERSION = 1;
export const TASK_POOL_ROOT_DIRECTORY_ID = "root";
export const TASK_POOL_ROOT_DIRECTORY_NAME = "根目录";
export const TASK_POOL_INBOX_DIRECTORY_ID = "inbox";
export const TASK_POOL_INBOX_DIRECTORY_NAME = "待整理";

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === "object" && !Array.isArray(value);

const normalizeText = (value: unknown, fallback: string): string => {
  if (typeof value !== "string") return fallback;
  const trimmed = value.trim();
  return trimmed || fallback;
};

const normalizeSortOrder = (value: unknown, fallback: number): number => {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
};

const uniqueBy = <T>(items: T[], getKey: (item: T) => string): T[] => {
  const seen = new Set<string>();
  const unique: T[] = [];

  for (const item of items) {
    const key = getKey(item);
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(item);
  }

  return unique;
};

const readDirectory = (value: unknown, fallbackIndex: number): TaskPoolDirectory | null => {
  if (!isRecord(value)) return null;
  if (typeof value.id !== "string" || !value.id.trim()) return null;

  return {
    id: value.id.trim(),
    name: normalizeText(value.name, "未命名目录"),
    parentDirectoryId:
      typeof value.parentDirectoryId === "string" && value.parentDirectoryId.trim()
        ? value.parentDirectoryId.trim()
        : undefined,
    sortOrder: normalizeSortOrder(value.sortOrder, fallbackIndex)
  };
};

const readTaskPlacement = (value: unknown, fallbackIndex: number): TaskPoolTaskPlacement | null => {
  if (!isRecord(value)) return null;
  if (typeof value.taskId !== "string" || !value.taskId.trim()) return null;

  return {
    taskId: value.taskId.trim(),
    parentDirectoryId:
      typeof value.parentDirectoryId === "string" && value.parentDirectoryId.trim()
        ? value.parentDirectoryId.trim()
        : TASK_POOL_INBOX_DIRECTORY_ID,
    sortOrder: normalizeSortOrder(value.sortOrder, fallbackIndex)
  };
};

const readCanvasNode = (value: unknown): TaskPoolCanvasNodeLayout | null => {
  if (!isRecord(value)) return null;
  if (typeof value.nodeId !== "string" || !value.nodeId.trim()) return null;
  if (value.nodeKind !== "directory" && value.nodeKind !== "task") return null;

  return {
    nodeId: value.nodeId.trim(),
    nodeKind: value.nodeKind,
    x: normalizeSortOrder(value.x, 0),
    y: normalizeSortOrder(value.y, 0),
    isCollapsed: Boolean(value.isCollapsed)
  };
};

export const createDefaultTaskPoolOrganizationDocument = (
  updatedAt = nowIso()
): TaskPoolOrganizationDocument => ({
  version: TASK_POOL_ORGANIZATION_VERSION,
  rootDirectoryId: TASK_POOL_ROOT_DIRECTORY_ID,
  inboxDirectoryId: TASK_POOL_INBOX_DIRECTORY_ID,
  directories: [
    {
      id: TASK_POOL_ROOT_DIRECTORY_ID,
      name: TASK_POOL_ROOT_DIRECTORY_NAME,
      sortOrder: 0
    },
    {
      id: TASK_POOL_INBOX_DIRECTORY_ID,
      name: TASK_POOL_INBOX_DIRECTORY_NAME,
      parentDirectoryId: TASK_POOL_ROOT_DIRECTORY_ID,
      sortOrder: 0
    }
  ],
  taskPlacements: [],
  canvasNodes: [],
  updatedAt
});

export const normalizeTaskPoolOrganizationDocument = (
  value: Partial<TaskPoolOrganizationDocument>
): TaskPoolOrganizationDocument => {
  const fallback = createDefaultTaskPoolOrganizationDocument(
    typeof value.updatedAt === "string" && value.updatedAt.trim() ? value.updatedAt.trim() : nowIso()
  );
  const rootDirectoryId =
    typeof value.rootDirectoryId === "string" && value.rootDirectoryId.trim()
      ? value.rootDirectoryId.trim()
      : fallback.rootDirectoryId;
  const inboxDirectoryId =
    typeof value.inboxDirectoryId === "string" && value.inboxDirectoryId.trim() && value.inboxDirectoryId !== rootDirectoryId
      ? value.inboxDirectoryId.trim()
      : fallback.inboxDirectoryId;

  const rawDirectories = Array.isArray(value.directories)
    ? value.directories
        .map((item, index) => readDirectory(item, index))
        .filter((item): item is TaskPoolDirectory => item !== null)
    : [];
  const providedRoot = rawDirectories.find((directory) => directory.id === rootDirectoryId);
  const providedInbox = rawDirectories.find((directory) => directory.id === inboxDirectoryId);
  const otherDirectories = uniqueBy(
    rawDirectories.filter((directory) => directory.id !== rootDirectoryId && directory.id !== inboxDirectoryId),
    (directory) => directory.id
  );

  const directories: TaskPoolDirectory[] = [
    {
      id: rootDirectoryId,
      name: providedRoot?.name ?? TASK_POOL_ROOT_DIRECTORY_NAME,
      sortOrder: 0
    },
    {
      id: inboxDirectoryId,
      name: providedInbox?.name ?? TASK_POOL_INBOX_DIRECTORY_NAME,
      parentDirectoryId: rootDirectoryId,
      sortOrder: 0
    }
  ];
  const knownDirectoryIDs = new Set([rootDirectoryId, inboxDirectoryId, ...otherDirectories.map((directory) => directory.id)]);

  for (const directory of otherDirectories) {
    const normalizedParent =
      directory.parentDirectoryId &&
      directory.parentDirectoryId !== directory.id &&
      knownDirectoryIDs.has(directory.parentDirectoryId)
        ? directory.parentDirectoryId
        : rootDirectoryId;

    directories.push({
      ...directory,
      parentDirectoryId: normalizedParent
    });
  }

  const taskPlacements = uniqueBy(
    Array.isArray(value.taskPlacements)
      ? value.taskPlacements
          .map((item, index) => readTaskPlacement(item, index))
          .filter((item): item is TaskPoolTaskPlacement => item !== null)
          .map((placement) => ({
            ...placement,
            parentDirectoryId: knownDirectoryIDs.has(placement.parentDirectoryId) ? placement.parentDirectoryId : inboxDirectoryId
          }))
      : [],
    (placement) => placement.taskId
  );

  const canvasNodes = uniqueBy(
    Array.isArray(value.canvasNodes)
      ? value.canvasNodes
          .map(readCanvasNode)
          .filter((item): item is TaskPoolCanvasNodeLayout => item !== null)
          .filter((item) => item.nodeKind !== "directory" || knownDirectoryIDs.has(item.nodeId))
      : [],
    (node) => `${node.nodeKind}:${node.nodeId}`
  );

  return {
    version:
      typeof value.version === "number" && Number.isFinite(value.version) && value.version > 0
        ? value.version
        : TASK_POOL_ORGANIZATION_VERSION,
    rootDirectoryId,
    inboxDirectoryId,
    directories,
    taskPlacements,
    canvasNodes,
    updatedAt:
      typeof value.updatedAt === "string" && value.updatedAt.trim() ? value.updatedAt.trim() : fallback.updatedAt
  };
};

export const parseTaskPoolOrganizationDocument = (
  value: unknown
): TaskPoolOrganizationDocument | null => {
  if (!isRecord(value)) return null;
  return normalizeTaskPoolOrganizationDocument(value as Partial<TaskPoolOrganizationDocument>);
};
