import {
  DEFAULT_TIME_TEMPLATE,
  appendTaskStep as appendTaskStepToTask,
  buildQuickTask,
  buildSchedulePresentation,
  completeTaskStep as completeTaskStepOnTask,
  createTaskPoolDirectory,
  createTasksFromSequence,
  createDefaultTaskPoolOrganizationDocument,
  deleteTaskPoolDirectory,
  getTaskPoolCanvasStableId,
  getCurrentTaskStep,
  makeTask,
  moveTaskPoolDirectory,
  normalizeTaskPoolOrganizationDocument,
  nowIso,
  parseQuickInput,
  placeTaskInTaskPool,
  renameTaskPoolDirectory,
  reorderTasksForSequence,
  resetTaskPoolCanvasPositions,
  setTaskStatus,
  sortNornTasks,
  updateTaskPoolCanvasNode,
  type Task,
  type TaskPoolOrganizationDocument,
  type TimeTemplate,
  type WeeklyTimeRange
} from "@retodo/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  mergeByLww,
  mergeTaskPoolOrganizationByLww,
  pullRemoteTasks,
  pushAndPullTasks
} from "../features/sync/data/taskSync";
import { downloadMarkdown, parseMarkdownImport } from "../shared/storage/taskTransfer";
import {
  isSyncConfigured,
  loadHideCompletedTasks,
  loadSyncSettings,
  saveHideCompletedTasks,
  saveSyncSettings as persistSyncSettings,
  type WebSyncSettings
} from "../shared/storage/syncSettingsStore";
import { loadTimeTemplate, saveTimeTemplate } from "../shared/storage/timeTemplateStore";
import { createId } from "../shared/utils/createId";

export type WebAppTab = "sequence" | "schedule" | "taskPool";
export type WebSyncState = "idle" | "syncing" | "error" | "notConfigured";

export interface WebTaskSequenceDraft {
  title: string;
  entries: string[];
}

export interface WebAppController {
  currentTab: WebAppTab;
  setCurrentTab: (tab: WebAppTab) => void;
  quickInput: string;
  setQuickInput: (value: string) => void;
  editingTask: Task | null;
  selectedTask: Task | null;
  openTaskDetail: (task: Task) => void;
  closeTaskDetail: () => void;
  openTaskEditor: (task: Task) => void;
  closeTaskEditor: () => void;
  openQuickAddEditor: () => void;
  taskSequenceDraft: WebTaskSequenceDraft | null;
  openQuickAddSequence: () => void;
  closeTaskSequence: () => void;
  saveTaskSequenceDraft: (draft: WebTaskSequenceDraft) => void;
  horizonDays: number;
  setHorizonDays: (days: number) => void;
  searchQuery: string;
  setSearchQuery: (value: string) => void;
  templateOpen: boolean;
  toggleTemplateOpen: () => void;
  timeTemplate: TimeTemplate;
  syncMessage: string;
  syncState: WebSyncState;
  isSyncConfigured: boolean;
  isSyncing: boolean;
  visibleTasks: Task[];
  filteredTasks: Task[];
  taskPoolOrganization: TaskPoolOrganizationDocument;
  syncSettings: WebSyncSettings;
  hideCompletedTasks: boolean;
  isSyncSettingsOpen: boolean;
  openSyncSettings: () => void;
  closeSyncSettings: () => void;
  saveSyncSettings: (settings: WebSyncSettings, hideCompletedTasks: boolean) => void;
  createTaskPoolDirectory: (name: string, parentDirectoryId?: string) => void;
  renameTaskPoolDirectory: (directoryId: string, name: string) => void;
  deleteTaskPoolDirectory: (directoryId: string) => void;
  moveTaskPoolDirectory: (directoryId: string, parentDirectoryId?: string) => void;
  placeTaskInTaskPool: (taskId: string, parentDirectoryId?: string) => void;
  updateTaskPoolCanvasNode: (
    nodeId: string,
    nodeKind: "directory" | "task",
    x: number,
    y: number,
    isCollapsed: boolean
  ) => void;
  resetTaskPoolCanvasLayout: (positionsByStableId: Record<string, { x: number; y: number }>) => void;
  focusedTask: Task | null;
  primarySequenceTasks: Task[];
  nextTasks: Task[];
  scheduleView: ReturnType<typeof buildSchedulePresentation>["scheduleView"];
  blocksByDay: ReturnType<typeof buildSchedulePresentation>["blocksByDay"];
  addTask: () => void;
  performSync: () => Promise<void>;
  toggleDone: (taskId: string) => void;
  archiveTask: (taskId: string) => void;
  deleteTask: (taskId: string) => void;
  promoteTaskToDoing: (taskId: string) => void;
  appendTaskStep: (taskId: string, title: string) => void;
  completeTaskStep: (taskId: string, stepId: string) => void;
  reorderPrimarySequence: (orderedTaskIds: string[]) => void;
  saveEditedTask: (updated: Task) => void;
  importMarkdownFile: (file: File | null) => Promise<void>;
  exportMarkdown: () => void;
  resetTimeTemplate: () => void;
  updateRange: (rangeId: string, patch: Partial<WeeklyTimeRange>) => void;
  addRange: () => void;
  removeRange: (rangeId: string) => void;
  getCurrentStepForTask: (task: Task) => Task["steps"][number] | null;
}

const PRIMARY_SEQUENCE_HORIZON_DAYS = 7;

const buildQuickTaskSeed = (input: string): Task => {
  const trimmed = input.trim();
  if (!trimmed) {
    return makeTask({
      id: createId(),
      title: "",
      rawInput: ""
    });
  }

  const parsed = parseQuickInput(trimmed);
  return makeTask({
    id: createId(),
    title: parsed.title,
    rawInput: trimmed,
    estimatedMinutes: parsed.estimatedMinutes,
    minChunkMinutes: parsed.minChunkMinutes,
    dueAt: parsed.dueAt,
    tags: parsed.tags
  });
};

const isWithinPrimarySequenceHorizon = (task: Task, now: Date): boolean => {
  if (!task.dueAt) return true;

  const dueAt = new Date(task.dueAt);
  const startOfToday = new Date(now);
  startOfToday.setHours(0, 0, 0, 0);
  dueAt.setHours(0, 0, 0, 0);

  const diffDays = Math.round((dueAt.getTime() - startOfToday.getTime()) / 86_400_000);
  return diffDays <= PRIMARY_SEQUENCE_HORIZON_DAYS;
};

const configuredSyncState = (settings: WebSyncSettings): { message: string; state: WebSyncState } =>
  isSyncConfigured(settings)
    ? { message: "未同步", state: "idle" }
    : { message: "未配置同步", state: "notConfigured" };

export const useWebAppController = (): WebAppController => {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [taskPoolOrganization, setTaskPoolOrganization] = useState<TaskPoolOrganizationDocument>(
    createDefaultTaskPoolOrganizationDocument()
  );
  const [currentTab, setCurrentTab] = useState<WebAppTab>("sequence");
  const [quickInput, setQuickInput] = useState("");
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [taskSequenceDraft, setTaskSequenceDraft] = useState<WebTaskSequenceDraft | null>(null);
  const [horizonDays, setHorizonDays] = useState<number>(7);
  const [searchQuery, setSearchQuery] = useState("");
  const [templateOpen, setTemplateOpen] = useState(false);
  const [timeTemplate, setTimeTemplate] = useState<TimeTemplate>(loadTimeTemplate());
  const [syncSettings, setSyncSettings] = useState<WebSyncSettings>(loadSyncSettings());
  const [hideCompletedTasks, setHideCompletedTasks] = useState(loadHideCompletedTasks());
  const [isSyncSettingsOpen, setIsSyncSettingsOpen] = useState(false);
  const [syncMessage, setSyncMessage] = useState(configuredSyncState(loadSyncSettings()).message);
  const [syncState, setSyncState] = useState<WebSyncState>(configuredSyncState(loadSyncSettings()).state);
  const [isSyncing, setIsSyncing] = useState(false);

  const tasksRef = useRef(tasks);
  const taskPoolOrganizationRef = useRef(taskPoolOrganization);
  const syncSettingsRef = useRef(syncSettings);
  const syncInFlightRef = useRef(false);

  useEffect(() => {
    tasksRef.current = tasks;
  }, [tasks]);

  useEffect(() => {
    taskPoolOrganizationRef.current = taskPoolOrganization;
  }, [taskPoolOrganization]);

  useEffect(() => {
    syncSettingsRef.current = syncSettings;
  }, [syncSettings]);

  useEffect(() => {
    saveTimeTemplate(timeTemplate);
  }, [timeTemplate]);

  const visibleTasks = useMemo(() => sortNornTasks(tasks.filter((task) => task.status !== "archived")), [tasks]);
  const selectedTask = useMemo(
    () => (selectedTaskId ? visibleTasks.find((task) => task.id === selectedTaskId) ?? null : null),
    [selectedTaskId, visibleTasks]
  );

  const schedulePresentation = useMemo(
    () => buildSchedulePresentation(visibleTasks, timeTemplate, horizonDays),
    [visibleTasks, timeTemplate, horizonDays]
  );

  const { scheduleView, blocksByDay } = schedulePresentation;

  const focusedTask = useMemo(
    () => visibleTasks.find((task) => task.status === "doing") ?? null,
    [visibleTasks]
  );

  const primarySequenceTasks = useMemo(
    () =>
      visibleTasks.filter(
        (task) =>
          task.status === "doing" || (task.status === "todo" && isWithinPrimarySequenceHorizon(task, new Date()))
      ),
    [visibleTasks]
  );

  const nextTasks = useMemo(
    () =>
      visibleTasks.filter(
        (task) => task.status === "todo" && !isWithinPrimarySequenceHorizon(task, new Date())
      ),
    [visibleTasks]
  );

  const taskPoolTasks = useMemo(
    () => visibleTasks.filter((task) => !hideCompletedTasks || task.status !== "done"),
    [hideCompletedTasks, visibleTasks]
  );

  const filteredTasks = useMemo(() => {
    if (!searchQuery.trim()) return taskPoolTasks;

    const query = searchQuery.trim().toLowerCase();
    return taskPoolTasks.filter(
      (task) =>
        task.title.toLowerCase().includes(query) ||
        (task.description ?? "").toLowerCase().includes(query) ||
        task.tags.some((tag) => tag.toLowerCase().includes(query))
    );
  }, [searchQuery, taskPoolTasks]);

  const applyLocalState = useCallback(
    (nextTasks: Task[], nextTaskPoolOrganization: TaskPoolOrganizationDocument) => {
      const orderedTasks = sortNornTasks(nextTasks);
      const normalizedOrganization = normalizeTaskPoolOrganizationDocument(nextTaskPoolOrganization);

      setTasks(orderedTasks);
      tasksRef.current = orderedTasks;

      setTaskPoolOrganization(normalizedOrganization);
      taskPoolOrganizationRef.current = normalizedOrganization;
    },
    []
  );

  const performSyncWithState = useCallback(
    async (
      tasksToPush: Task[] = tasksRef.current,
      taskPoolOrganizationToPush: TaskPoolOrganizationDocument = taskPoolOrganizationRef.current
    ) => {
      const settings = syncSettingsRef.current;
      if (!isSyncConfigured(settings)) {
        setSyncState("notConfigured");
        setSyncMessage("未配置同步");
        return;
      }

      if (syncInFlightRef.current) return;
      syncInFlightRef.current = true;
      setIsSyncing(true);
      setSyncState("syncing");
      setSyncMessage("同步中…");
      try {
        const remote = await pushAndPullTasks(settings, tasksToPush, taskPoolOrganizationToPush);
        applyLocalState(remote.tasks, remote.taskPoolOrganization ?? taskPoolOrganizationToPush);
        setSyncState("idle");
        setSyncMessage(`已同步 ${new Date().toLocaleTimeString()}`);
      } catch (error) {
        setSyncState("error");
        setSyncMessage(`同步失败: ${error instanceof Error ? error.message : String(error)}`);
      } finally {
        syncInFlightRef.current = false;
        setIsSyncing(false);
      }
    },
    [applyLocalState]
  );

  const pullOnly = useCallback(async () => {
    const settings = syncSettingsRef.current;
    if (!isSyncConfigured(settings)) {
      setSyncState("notConfigured");
      setSyncMessage("未配置同步");
      return;
    }

    if (syncInFlightRef.current) return;
    try {
      const remote = await pullRemoteTasks(settings);
      const mergedTasks = mergeByLww(tasksRef.current, remote.tasks);
      const mergedOrganization = mergeTaskPoolOrganizationByLww(
        taskPoolOrganizationRef.current,
        remote.taskPoolOrganization
      );
      applyLocalState(mergedTasks, mergedOrganization);
      setSyncState("idle");
      setSyncMessage(`已拉取 ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setSyncState("error");
      setSyncMessage(`拉取失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }, [applyLocalState]);

  const commitState = useCallback(
    (nextTasks: Task[], nextTaskPoolOrganization: TaskPoolOrganizationDocument = taskPoolOrganizationRef.current) => {
      applyLocalState(nextTasks, nextTaskPoolOrganization);
      void performSyncWithState(sortNornTasks(nextTasks), nextTaskPoolOrganization);
    },
    [applyLocalState, performSyncWithState]
  );

  useEffect(() => {
    void pullOnly();
  }, [pullOnly]);

  useEffect(() => {
    const timer = window.setInterval(() => void pullOnly(), 7000);
    return () => window.clearInterval(timer);
  }, [pullOnly]);

  const mutateTask = useCallback(
    (taskId: string, recipe: (task: Task) => Task | null) => {
      let changed = false;
      const next = tasksRef.current.map((task) => {
        if (task.id !== taskId) return task;
        const updated = recipe(task);
        if (!updated) return task;
        changed = changed || updated !== task;
        return updated;
      });

      if (!changed) return;
      commitState(next);
    },
    [commitState]
  );

  const addTask = useCallback(() => {
    if (!quickInput.trim()) return;
    const nextTask = buildQuickTask(createId(), quickInput);
    commitState([nextTask, ...tasksRef.current]);
    setQuickInput("");
  }, [commitState, quickInput]);

  const toggleDone = useCallback(
    (taskId: string) => {
      mutateTask(taskId, (task) =>
        setTaskStatus(task, task.status === "done" ? "todo" : "done", nowIso())
      );
    },
    [mutateTask]
  );

  const archiveTask = useCallback(
    (taskId: string) => {
      mutateTask(taskId, (task) => ({
        ...task,
        status: "archived",
        updatedAt: nowIso()
      }));

      if (selectedTaskId === taskId) {
        setSelectedTaskId(null);
      }
      if (editingTask?.id === taskId) {
        setEditingTask(null);
      }
    },
    [editingTask?.id, mutateTask, selectedTaskId]
  );

  const deleteTask = useCallback(
    (taskId: string) => {
      const nextTasks = tasksRef.current.filter((task) => task.id !== taskId);
      if (nextTasks.length === tasksRef.current.length) return;

      commitState(nextTasks);
      if (selectedTaskId === taskId) {
        setSelectedTaskId(null);
      }
      if (editingTask?.id === taskId) {
        setEditingTask(null);
      }
    },
    [commitState, editingTask?.id, selectedTaskId]
  );

  const promoteTaskToDoing = useCallback(
    (taskId: string) => {
      mutateTask(taskId, (task) => setTaskStatus(task, "doing", nowIso()));
    },
    [mutateTask]
  );

  const appendTaskStep = useCallback(
    (taskId: string, title: string) => {
      mutateTask(taskId, (task) => {
        const updated = appendTaskStepToTask(task, title, nowIso());
        return updated.updatedAt === task.updatedAt && updated.steps.length === task.steps.length ? null : updated;
      });
    },
    [mutateTask]
  );

  const completeTaskStep = useCallback(
    (taskId: string, stepId: string) => {
      mutateTask(taskId, (task) => completeTaskStepOnTask(task, stepId, nowIso()));
    },
    [mutateTask]
  );

  const reorderPrimarySequence = useCallback(
    (orderedTaskIds: string[]) => {
      const next = reorderTasksForSequence(tasksRef.current, orderedTaskIds, nowIso());
      const changed = next.some((task, index) => task !== tasksRef.current[index]);
      if (!changed) return;
      commitState(next);
    },
    [commitState]
  );

  const saveEditedTask = useCallback(
    (updated: Task) => {
      const existingIndex = tasksRef.current.findIndex((task) => task.id === updated.id);
      if (existingIndex >= 0) {
        commitState(tasksRef.current.map((task) => (task.id === updated.id ? updated : task)));
      } else {
        commitState([updated, ...tasksRef.current]);
      }
      setEditingTask(null);
      setSelectedTaskId(updated.id);
    },
    [commitState]
  );

  const importMarkdownFile = useCallback(
    async (file: File | null) => {
      if (!file) return;
      const text = await file.text();
      const lines = parseMarkdownImport(text);
      if (lines.length === 0) return;

      const imported = lines.map((line) => buildQuickTask(createId(), line));
      commitState([...imported, ...tasksRef.current]);
    },
    [commitState]
  );

  const saveTaskSequenceDraft = useCallback(
    (draft: WebTaskSequenceDraft) => {
      const createdTasks = createTasksFromSequence({
        title: draft.title,
        rawInputs: draft.entries,
        taskIdGenerator: createId,
        bundleIdGenerator: createId
      });

      if (createdTasks.length === 0) {
        setTaskSequenceDraft(null);
        return;
      }

      commitState([...createdTasks, ...tasksRef.current]);
      setTaskSequenceDraft(null);
    },
    [commitState]
  );

  const updateRange = useCallback((rangeId: string, patch: Partial<WeeklyTimeRange>) => {
    setTimeTemplate((current) => ({
      ...current,
      weeklyRanges: current.weeklyRanges.map((range) => (range.id === rangeId ? { ...range, ...patch } : range))
    }));
  }, []);

  const addRange = useCallback(() => {
    const nextId = createId();
    setTimeTemplate((current) => ({
      ...current,
      weeklyRanges: [
        ...current.weeklyRanges,
        {
          id: nextId,
          weekday: 1,
          startTime: "09:00",
          endTime: "10:00"
        }
      ]
    }));
  }, []);

  const removeRange = useCallback((rangeId: string) => {
    setTimeTemplate((current) => ({
      ...current,
      weeklyRanges: current.weeklyRanges.filter((range) => range.id !== rangeId)
    }));
  }, []);

  const saveRuntimeSyncSettings = useCallback((settings: WebSyncSettings, hideCompleted: boolean) => {
    const normalizedSettings = persistSyncSettings(settings);
    const normalizedHideCompleted = saveHideCompletedTasks(hideCompleted);

    setSyncSettings(normalizedSettings);
    syncSettingsRef.current = normalizedSettings;

    setHideCompletedTasks(normalizedHideCompleted);

    if (isSyncConfigured(normalizedSettings)) {
      setSyncState("idle");
      setSyncMessage("同步配置已保存");
    } else {
      setSyncState("notConfigured");
      setSyncMessage("未配置同步");
    }

    setIsSyncSettingsOpen(false);
  }, []);

  const createTaskPoolDirectoryEntry = useCallback(
    (name: string, parentDirectoryId?: string) => {
      const nextOrganization = createTaskPoolDirectory(taskPoolOrganizationRef.current, {
        directoryId: createId(),
        name,
        ...(parentDirectoryId ? { parentDirectoryId } : {}),
        updatedAt: nowIso()
      });
      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  const renameTaskPoolDirectoryEntry = useCallback(
    (directoryId: string, name: string) => {
      const nextOrganization = renameTaskPoolDirectory(taskPoolOrganizationRef.current, {
        directoryId,
        name,
        updatedAt: nowIso()
      });
      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  const deleteTaskPoolDirectoryEntry = useCallback(
    (directoryId: string) => {
      const nextOrganization = deleteTaskPoolDirectory(taskPoolOrganizationRef.current, {
        directoryId,
        updatedAt: nowIso()
      });
      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  const moveTaskPoolDirectoryEntry = useCallback(
    (directoryId: string, parentDirectoryId?: string) => {
      const nextOrganization = moveTaskPoolDirectory(taskPoolOrganizationRef.current, {
        directoryId,
        ...(parentDirectoryId ? { parentDirectoryId } : {}),
        updatedAt: nowIso()
      });
      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  const placeTaskInTaskPoolEntry = useCallback(
    (taskId: string, parentDirectoryId?: string) => {
      const nextOrganization = placeTaskInTaskPool(taskPoolOrganizationRef.current, {
        taskId,
        ...(parentDirectoryId ? { parentDirectoryId } : {}),
        updatedAt: nowIso()
      });
      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  const updateTaskPoolCanvasNodeEntry = useCallback(
    (
      nodeId: string,
      nodeKind: "directory" | "task",
      x: number,
      y: number,
      isCollapsed: boolean
    ) => {
      const nextOrganization = updateTaskPoolCanvasNode(taskPoolOrganizationRef.current, {
        nodeId,
        nodeKind,
        x,
        y,
        isCollapsed,
        updatedAt: nowIso()
      });
      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  const resetTaskPoolCanvasLayout = useCallback(
    (positionsByStableId: Record<string, { x: number; y: number }>) => {
      const normalizedOrganization = normalizeTaskPoolOrganizationDocument(taskPoolOrganizationRef.current);
      let nextOrganization = resetTaskPoolCanvasPositions(normalizedOrganization, {
        positionsByStableId,
        updatedAt: nowIso()
      });

      const existingStableIds = new Set(
        normalizedOrganization.canvasNodes.map((node) =>
          getTaskPoolCanvasStableId(node.nodeKind, node.nodeId)
        )
      );

      for (const [stableId, position] of Object.entries(positionsByStableId)) {
        if (existingStableIds.has(stableId)) continue;

        const [nodeKind, ...nodeIdParts] = stableId.split(":");
        const nodeId = nodeIdParts.join(":");
        if (!nodeId) continue;
        if (nodeKind !== "directory" && nodeKind !== "task") continue;

        nextOrganization = updateTaskPoolCanvasNode(nextOrganization, {
          nodeId,
          nodeKind,
          x: position.x,
          y: position.y,
          isCollapsed: false,
          updatedAt: nowIso()
        });
      }

      commitState(tasksRef.current, nextOrganization);
    },
    [commitState]
  );

  return {
    currentTab,
    setCurrentTab,
    quickInput,
    setQuickInput,
    editingTask,
    selectedTask,
    openTaskDetail: (task) => {
      setSelectedTaskId(task.id);
    },
    closeTaskDetail: () => setSelectedTaskId(null),
    openTaskEditor: (task) => {
      setSelectedTaskId(null);
      setEditingTask(task);
    },
    closeTaskEditor: () => setEditingTask(null),
    openQuickAddEditor: () => {
      setSelectedTaskId(null);
      setTaskSequenceDraft(null);
      setEditingTask(buildQuickTaskSeed(quickInput));
      setQuickInput("");
    },
    taskSequenceDraft,
    openQuickAddSequence: () => {
      setSelectedTaskId(null);
      setEditingTask(null);
      setTaskSequenceDraft({
        title: "",
        entries: [quickInput.trim() || ""]
      });
      setQuickInput("");
    },
    closeTaskSequence: () => setTaskSequenceDraft(null),
    saveTaskSequenceDraft,
    horizonDays,
    setHorizonDays,
    searchQuery,
    setSearchQuery,
    templateOpen,
    toggleTemplateOpen: () => setTemplateOpen((current) => !current),
    timeTemplate,
    syncMessage,
    syncState,
    isSyncConfigured: isSyncConfigured(syncSettings),
    isSyncing,
    visibleTasks,
    filteredTasks,
    taskPoolOrganization,
    syncSettings,
    hideCompletedTasks,
    isSyncSettingsOpen,
    openSyncSettings: () => setIsSyncSettingsOpen(true),
    closeSyncSettings: () => setIsSyncSettingsOpen(false),
    saveSyncSettings: saveRuntimeSyncSettings,
    createTaskPoolDirectory: createTaskPoolDirectoryEntry,
    renameTaskPoolDirectory: renameTaskPoolDirectoryEntry,
    deleteTaskPoolDirectory: deleteTaskPoolDirectoryEntry,
    moveTaskPoolDirectory: moveTaskPoolDirectoryEntry,
    placeTaskInTaskPool: placeTaskInTaskPoolEntry,
    updateTaskPoolCanvasNode: updateTaskPoolCanvasNodeEntry,
    resetTaskPoolCanvasLayout,
    focusedTask,
    primarySequenceTasks,
    nextTasks,
    scheduleView,
    blocksByDay,
    addTask,
    performSync: () => performSyncWithState(),
    toggleDone,
    archiveTask,
    deleteTask,
    promoteTaskToDoing,
    appendTaskStep,
    completeTaskStep,
    reorderPrimarySequence,
    saveEditedTask,
    importMarkdownFile,
    exportMarkdown: () => downloadMarkdown(visibleTasks),
    resetTimeTemplate: () => setTimeTemplate(DEFAULT_TIME_TEMPLATE),
    updateRange,
    addRange,
    removeRange,
    getCurrentStepForTask: (task) => getCurrentTaskStep(task)
  };
};
