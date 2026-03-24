import {
  DEFAULT_TIME_TEMPLATE,
  appendTaskStep as appendTaskStepToTask,
  buildQuickTask,
  buildSchedulePresentation,
  completeTaskStep as completeTaskStepOnTask,
  getCurrentTaskStep,
  makeTask,
  nowIso,
  parseQuickInput,
  reorderTasksForSequence,
  setTaskStatus,
  sortNornTasks,
  type Task,
  type TimeTemplate,
  type WeeklyTimeRange
} from "@retodo/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { mergeByLww, pullRemoteTasks, pushAndPullTasks } from "../features/sync/data/taskSync";
import { API_BASE_URL } from "../shared/config/env";
import { getOrCreateDeviceId } from "../shared/storage/deviceSession";
import { downloadMarkdown, parseMarkdownImport } from "../shared/storage/taskTransfer";
import { loadTimeTemplate, saveTimeTemplate } from "../shared/storage/timeTemplateStore";
import { createId } from "../shared/utils/createId";

export type WebAppTab = "sequence" | "schedule" | "taskPool";

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
  horizonDays: number;
  setHorizonDays: (days: number) => void;
  searchQuery: string;
  setSearchQuery: (value: string) => void;
  templateOpen: boolean;
  toggleTemplateOpen: () => void;
  timeTemplate: TimeTemplate;
  syncMessage: string;
  isSyncing: boolean;
  visibleTasks: Task[];
  filteredTasks: Task[];
  focusedTask: Task | null;
  primarySequenceTasks: Task[];
  nextTasks: Task[];
  scheduleView: ReturnType<typeof buildSchedulePresentation>["scheduleView"];
  blocksByDay: ReturnType<typeof buildSchedulePresentation>["blocksByDay"];
  addTask: () => void;
  performSync: () => Promise<void>;
  toggleDone: (taskId: string) => void;
  archiveTask: (taskId: string) => void;
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

export const useWebAppController = (): WebAppController => {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [currentTab, setCurrentTab] = useState<WebAppTab>("sequence");
  const [quickInput, setQuickInput] = useState("");
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [horizonDays, setHorizonDays] = useState<number>(7);
  const [searchQuery, setSearchQuery] = useState("");
  const [templateOpen, setTemplateOpen] = useState(false);
  const [timeTemplate, setTimeTemplate] = useState<TimeTemplate>(loadTimeTemplate());
  const [syncMessage, setSyncMessage] = useState("未同步");
  const [isSyncing, setIsSyncing] = useState(false);

  const tasksRef = useRef(tasks);
  const deviceIdRef = useRef(getOrCreateDeviceId());
  const syncInFlightRef = useRef(false);

  useEffect(() => {
    tasksRef.current = tasks;
  }, [tasks]);

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
        (task) =>
          task.status === "todo" && !isWithinPrimarySequenceHorizon(task, new Date())
      ),
    [visibleTasks]
  );

  const filteredTasks = useMemo(() => {
    if (!searchQuery.trim()) return visibleTasks;

    const query = searchQuery.trim().toLowerCase();
    return visibleTasks.filter(
      (task) =>
        task.title.toLowerCase().includes(query) ||
        (task.description ?? "").toLowerCase().includes(query) ||
        task.tags.some((tag) => tag.toLowerCase().includes(query))
    );
  }, [searchQuery, visibleTasks]);

  const applyRemoteTasks = useCallback((incoming: Task[]) => {
    const next = sortNornTasks(incoming);
    setTasks(next);
    tasksRef.current = next;
  }, []);

  const performSyncWithTasks = useCallback(
    async (tasksToPush?: Task[]) => {
      if (syncInFlightRef.current) return;
      syncInFlightRef.current = true;
      setIsSyncing(true);
      try {
        const remote = await pushAndPullTasks(API_BASE_URL, deviceIdRef.current, tasksToPush ?? tasksRef.current);
        applyRemoteTasks(remote);
        setSyncMessage(`已同步 ${new Date().toLocaleTimeString()}`);
      } catch (error) {
        setSyncMessage(`同步失败: ${error instanceof Error ? error.message : String(error)}`);
      } finally {
        syncInFlightRef.current = false;
        setIsSyncing(false);
      }
    },
    [applyRemoteTasks]
  );

  const pullOnly = useCallback(async () => {
    if (syncInFlightRef.current) return;
    try {
      const remote = await pullRemoteTasks(API_BASE_URL);
      const merged = mergeByLww(tasksRef.current, remote);
      applyRemoteTasks(merged);
      setSyncMessage(`已拉取 ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setSyncMessage(`拉取失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }, [applyRemoteTasks]);

  const commitTasks = useCallback(
    (next: Task[]) => {
      const ordered = sortNornTasks(next);
      setTasks(ordered);
      tasksRef.current = ordered;
      void performSyncWithTasks(ordered);
    },
    [performSyncWithTasks]
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
      commitTasks(next);
    },
    [commitTasks]
  );

  const addTask = useCallback(() => {
    if (!quickInput.trim()) return;
    const nextTask = buildQuickTask(createId(), quickInput);
    commitTasks([nextTask, ...tasksRef.current]);
    setQuickInput("");
  }, [commitTasks, quickInput]);

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
      commitTasks(next);
    },
    [commitTasks]
  );

  const saveEditedTask = useCallback(
    (updated: Task) => {
      const existingIndex = tasksRef.current.findIndex((task) => task.id === updated.id);
      if (existingIndex >= 0) {
        commitTasks(tasksRef.current.map((task) => (task.id === updated.id ? updated : task)));
      } else {
        commitTasks([updated, ...tasksRef.current]);
      }
      setEditingTask(null);
      setSelectedTaskId(updated.id);
    },
    [commitTasks]
  );

  const importMarkdownFile = useCallback(
    async (file: File | null) => {
      if (!file) return;
      const text = await file.text();
      const lines = parseMarkdownImport(text);
      if (lines.length === 0) return;

      const imported = lines.map((line) => buildQuickTask(createId(), line));
      commitTasks([...imported, ...tasksRef.current]);
    },
    [commitTasks]
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
      setEditingTask(buildQuickTaskSeed(quickInput));
      setQuickInput("");
    },
    horizonDays,
    setHorizonDays,
    searchQuery,
    setSearchQuery,
    templateOpen,
    toggleTemplateOpen: () => setTemplateOpen((current) => !current),
    timeTemplate,
    syncMessage,
    isSyncing,
    visibleTasks,
    filteredTasks,
    focusedTask,
    primarySequenceTasks,
    nextTasks,
    scheduleView,
    blocksByDay,
    addTask,
    performSync: () => performSyncWithTasks(),
    toggleDone,
    archiveTask,
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
