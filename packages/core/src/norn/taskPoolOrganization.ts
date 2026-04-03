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

export const getTaskPoolDirectory = (
  document: TaskPoolOrganizationDocument,
  directoryId: string
): TaskPoolDirectory | null =>
  normalizeTaskPoolOrganizationDocument(document).directories.find((directory) => directory.id === directoryId) ?? null;

export const getTaskPoolTaskPlacement = (
  document: TaskPoolOrganizationDocument,
  taskId: string
): TaskPoolTaskPlacement | null =>
  normalizeTaskPoolOrganizationDocument(document).taskPlacements.find((placement) => placement.taskId === taskId) ?? null;

export const getTaskPoolTaskDirectoryId = (
  document: TaskPoolOrganizationDocument,
  taskId: string
): string =>
  getTaskPoolTaskPlacement(document, taskId)?.parentDirectoryId ??
  normalizeTaskPoolOrganizationDocument(document).inboxDirectoryId;

export const getTaskPoolChildDirectories = (
  document: TaskPoolOrganizationDocument,
  parentDirectoryId?: string
): TaskPoolDirectory[] =>
  normalizeTaskPoolOrganizationDocument(document).directories
    .filter((directory) => directory.parentDirectoryId === parentDirectoryId)
    .sort(compareDirectories);

export const getTaskPoolDirectoryPath = (
  document: TaskPoolOrganizationDocument,
  directoryId: string
): TaskPoolDirectory[] => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const path: TaskPoolDirectory[] = [];
  let currentId: string | undefined = directoryId;

  while (currentId) {
    const directory = normalized.directories.find((candidate) => candidate.id === currentId);
    if (!directory) break;
    path.unshift(directory);
    currentId = directory.parentDirectoryId;
  }

  return path;
};

export const createTaskPoolDirectory = (
  document: TaskPoolOrganizationDocument,
  input: {
    directoryId: string;
    name: string;
    parentDirectoryId?: string;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const directoryId = input.directoryId.trim();
  const name = input.name.trim();

  if (!directoryId || !name) return normalized;
  if (getTaskPoolDirectory(normalized, directoryId)) return normalized;

  const parentDirectoryId = normalizeParentDirectoryId(normalized, input.parentDirectoryId, directoryId);
  return normalizeTaskPoolOrganizationDocument({
    ...normalized,
    directories: [
      ...normalized.directories,
      {
        id: directoryId,
        name,
        parentDirectoryId,
        sortOrder: nextDirectorySortOrder(normalized, parentDirectoryId)
      }
    ],
    updatedAt: input.updatedAt ?? nowIso()
  });
};

export const renameTaskPoolDirectory = (
  document: TaskPoolOrganizationDocument,
  input: {
    directoryId: string;
    name: string;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const name = input.name.trim();
  if (!name) return normalized;

  const index = normalized.directories.findIndex((directory) => directory.id === input.directoryId);
  if (index < 0) return normalized;

  const nextDirectories = [...normalized.directories];
  const targetDirectory = nextDirectories[index];
  if (!targetDirectory) return normalized;
  nextDirectories[index] = {
    id: targetDirectory.id,
    parentDirectoryId: targetDirectory.parentDirectoryId,
    sortOrder: targetDirectory.sortOrder,
    name
  };

  return normalizeTaskPoolOrganizationDocument({
    ...normalized,
    directories: nextDirectories,
    updatedAt: input.updatedAt ?? nowIso()
  });
};

export const deleteTaskPoolDirectory = (
  document: TaskPoolOrganizationDocument,
  input: {
    directoryId: string;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const { directoryId } = input;

  if (
    directoryId === normalized.rootDirectoryId ||
    directoryId === normalized.inboxDirectoryId ||
    !getTaskPoolDirectory(normalized, directoryId)
  ) {
    return normalized;
  }

  let nextInboxDirectorySortOrder = nextDirectorySortOrder(normalized, normalized.inboxDirectoryId);
  const nextDirectories = normalized.directories.flatMap((directory) => {
    if (directory.id === directoryId) {
      return [];
    }

    if (directory.parentDirectoryId !== directoryId) {
      return [directory];
    }

    const movedDirectory: TaskPoolDirectory = {
      ...directory,
      parentDirectoryId: normalized.inboxDirectoryId,
      sortOrder: nextInboxDirectorySortOrder
    };
    nextInboxDirectorySortOrder += 1;
    return [movedDirectory];
  });

  let nextInboxTaskSortOrder = nextTaskSortOrder(normalized, normalized.inboxDirectoryId);
  const nextPlacements = normalized.taskPlacements.map((placement) => {
    if (placement.parentDirectoryId !== directoryId) {
      return placement;
    }

    const movedPlacement: TaskPoolTaskPlacement = {
      ...placement,
      parentDirectoryId: normalized.inboxDirectoryId,
      sortOrder: nextInboxTaskSortOrder
    };
    nextInboxTaskSortOrder += 1;
    return movedPlacement;
  });

  return normalizeTaskPoolOrganizationDocument({
    ...normalized,
    directories: nextDirectories,
    taskPlacements: nextPlacements,
    canvasNodes: normalized.canvasNodes.filter(
      (node) => !(node.nodeKind === "directory" && node.nodeId === directoryId)
    ),
    updatedAt: input.updatedAt ?? nowIso()
  });
};

export const moveTaskPoolDirectory = (
  document: TaskPoolOrganizationDocument,
  input: {
    directoryId: string;
    parentDirectoryId?: string;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const { directoryId } = input;

  if (directoryId === normalized.rootDirectoryId || directoryId === normalized.inboxDirectoryId) {
    return normalized;
  }

  const index = normalized.directories.findIndex((directory) => directory.id === directoryId);
  if (index < 0) return normalized;

  const descendants = getDescendantDirectoryIds(normalized, directoryId);
  const requestedParentId = normalizeParentDirectoryId(normalized, input.parentDirectoryId, directoryId);
  const parentDirectoryId =
    requestedParentId && !descendants.has(requestedParentId) ? requestedParentId : normalized.rootDirectoryId;

  const nextDirectories = [...normalized.directories];
  const targetDirectory = nextDirectories[index];
  if (!targetDirectory) return normalized;
  nextDirectories[index] = {
    id: targetDirectory.id,
    name: targetDirectory.name,
    parentDirectoryId,
    sortOrder: nextDirectorySortOrder(normalized, parentDirectoryId, directoryId)
  };

  return normalizeTaskPoolOrganizationDocument({
    ...normalized,
    directories: nextDirectories,
    updatedAt: input.updatedAt ?? nowIso()
  });
};

export const placeTaskInTaskPool = (
  document: TaskPoolOrganizationDocument,
  input: {
    taskId: string;
    parentDirectoryId?: string;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const taskId = input.taskId.trim();
  if (!taskId) return normalized;

  const parentDirectoryId =
    normalizeParentDirectoryId(normalized, input.parentDirectoryId) ?? normalized.inboxDirectoryId;
  const placementIndex = normalized.taskPlacements.findIndex((placement) => placement.taskId === taskId);
  const nextPlacements = [...normalized.taskPlacements];

  if (placementIndex >= 0) {
    const existingPlacement = nextPlacements[placementIndex];
    if (!existingPlacement) return normalized;
    nextPlacements[placementIndex] = {
      taskId: existingPlacement.taskId,
      parentDirectoryId,
      sortOrder: nextTaskSortOrder(normalized, parentDirectoryId, taskId)
    };
  } else {
    nextPlacements.push({
      taskId,
      parentDirectoryId,
      sortOrder: nextTaskSortOrder(normalized, parentDirectoryId)
    });
  }

  return normalizeTaskPoolOrganizationDocument({
    ...normalized,
    taskPlacements: nextPlacements,
    updatedAt: input.updatedAt ?? nowIso()
  });
};

export const updateTaskPoolCanvasNode = (
  document: TaskPoolOrganizationDocument,
  input: {
    nodeId: string;
    nodeKind: TaskPoolCanvasNodeLayout["nodeKind"];
    x: number;
    y: number;
    isCollapsed: boolean;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);
  const nodeId = input.nodeId.trim();
  if (!nodeId) return normalized;
  if (input.nodeKind === "directory" && !getTaskPoolDirectory(normalized, nodeId)) {
    return normalized;
  }

  const replacement: TaskPoolCanvasNodeLayout = {
    nodeId,
    nodeKind: input.nodeKind,
    x: Number.isFinite(input.x) ? input.x : 0,
    y: Number.isFinite(input.y) ? input.y : 0,
    isCollapsed: Boolean(input.isCollapsed)
  };
  const index = normalized.canvasNodes.findIndex(
    (node) => node.nodeId === nodeId && node.nodeKind === input.nodeKind
  );
  const nextCanvasNodes = [...normalized.canvasNodes];

  if (index >= 0) {
    nextCanvasNodes[index] = replacement;
  } else {
    nextCanvasNodes.push(replacement);
  }

  return normalizeTaskPoolOrganizationDocument({
    ...normalized,
    canvasNodes: nextCanvasNodes,
    updatedAt: input.updatedAt ?? nowIso()
  });
};

export const resetTaskPoolCanvasPositions = (
  document: TaskPoolOrganizationDocument,
  input: {
    positionsByStableId: Record<string, { x: number; y: number }>;
    updatedAt?: string;
  }
): TaskPoolOrganizationDocument => {
  const normalized = normalizeTaskPoolOrganizationDocument(document);

  return {
    ...normalized,
    canvasNodes: normalized.canvasNodes.map((node) => {
      const stableId = getTaskPoolCanvasStableId(node.nodeKind, node.nodeId);
      const position = input.positionsByStableId[stableId];
      if (!position) return node;

      return {
        ...node,
        x: Number.isFinite(position.x) ? position.x : node.x,
        y: Number.isFinite(position.y) ? position.y : node.y
      };
    }),
    updatedAt: input.updatedAt ?? nowIso()
  };
};

export const getTaskPoolCanvasStableId = (
  nodeKind: TaskPoolCanvasNodeLayout["nodeKind"],
  nodeId: string
): string => `${nodeKind}:${nodeId}`;

const compareDirectories = (left: TaskPoolDirectory, right: TaskPoolDirectory): number => {
  if (left.sortOrder !== right.sortOrder) {
    return left.sortOrder - right.sortOrder;
  }

  return left.name.localeCompare(right.name, "zh-CN", { sensitivity: "base" });
};

const getDescendantDirectoryIds = (
  document: TaskPoolOrganizationDocument,
  directoryId: string
): Set<string> => {
  const childIds = document.directories
    .filter((directory) => directory.parentDirectoryId === directoryId)
    .map((directory) => directory.id);

  const descendants = new Set(childIds);
  for (const childId of childIds) {
    for (const descendant of getDescendantDirectoryIds(document, childId)) {
      descendants.add(descendant);
    }
  }

  return descendants;
};

const normalizeParentDirectoryId = (
  document: TaskPoolOrganizationDocument,
  parentDirectoryId?: string,
  excludedDirectoryId?: string
): string | undefined => {
  if (!parentDirectoryId) {
    return document.rootDirectoryId;
  }

  if (parentDirectoryId === excludedDirectoryId) {
    return document.rootDirectoryId;
  }

  return document.directories.some((directory) => directory.id === parentDirectoryId)
    ? parentDirectoryId
    : document.rootDirectoryId;
};

const nextDirectorySortOrder = (
  document: TaskPoolOrganizationDocument,
  parentDirectoryId?: string,
  excludedDirectoryId?: string
): number => {
  const siblingSortOrders = document.directories
    .filter(
      (directory) =>
        directory.parentDirectoryId === parentDirectoryId && directory.id !== excludedDirectoryId
    )
    .map((directory) => directory.sortOrder);

  return (siblingSortOrders.length > 0 ? Math.max(...siblingSortOrders) : -1) + 1;
};

const nextTaskSortOrder = (
  document: TaskPoolOrganizationDocument,
  parentDirectoryId: string,
  excludedTaskId?: string
): number => {
  const siblingSortOrders = document.taskPlacements
    .filter(
      (placement) =>
        placement.parentDirectoryId === parentDirectoryId && placement.taskId !== excludedTaskId
    )
    .map((placement) => placement.sortOrder);

  return (siblingSortOrders.length > 0 ? Math.max(...siblingSortOrders) : -1) + 1;
};
