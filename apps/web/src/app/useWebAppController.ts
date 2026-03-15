import {
  DEFAULT_TIME_TEMPLATE,
  buildQuickTask,
  buildSchedulePresentation,
  makeTask,
  type Task,
  type TimeTemplate,
  type WeeklyTimeRange
} from "@retodo/core";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { pullRemoteTasks, pushAndPullTasks } from "../features/sync/data/taskSync";
import { API_BASE_URL } from "../shared/config/env";
import { getOrCreateDeviceId } from "../shared/storage/deviceSession";
import { downloadMarkdown, parseMarkdownImport } from "../shared/storage/taskTransfer";
import { loadTimeTemplate, saveTimeTemplate } from "../shared/storage/timeTemplateStore";
import { createId } from "../shared/utils/createId";

export interface WebAppController {
  quickInput: string;
  setQuickInput: (value: string) => void;
  editingTask: Task | null;
  openTaskEditor: (task: Task) => void;
  closeTaskEditor: () => void;
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
  scheduleView: ReturnType<typeof buildSchedulePresentation>["scheduleView"];
  blocksByDay: ReturnType<typeof buildSchedulePresentation>["blocksByDay"];
  addTask: () => void;
  performSync: () => Promise<void>;
  toggleDone: (taskId: string) => void;
  archiveTask: (taskId: string) => void;
  saveEditedTask: (updated: Task) => void;
  importMarkdownFile: (file: File | null) => Promise<void>;
  exportMarkdown: () => void;
  resetTimeTemplate: () => void;
  updateRange: (rangeId: string, patch: Partial<WeeklyTimeRange>) => void;
  addRange: () => void;
  removeRange: (rangeId: string) => void;
}

export const useWebAppController = (): WebAppController => {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [quickInput, setQuickInput] = useState("");
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

  const visibleTasks = useMemo(() => tasks.filter((task) => task.status !== "archived"), [tasks]);

  const schedulePresentation = useMemo(
    () => buildSchedulePresentation(visibleTasks, timeTemplate, horizonDays),
    [visibleTasks, timeTemplate, horizonDays]
  );

  const { scheduleView, blocksByDay } = schedulePresentation;

  const orderedTaskIds = useMemo(() => {
    const ids = new Set<string>();
    for (const step of scheduleView.orderedSteps) ids.add(step.taskId);
    return [...ids];
  }, [scheduleView.orderedSteps]);

  const filteredTasks = useMemo(() => {
    const byId = new Map(visibleTasks.map((task) => [task.id, task]));
    const ordered = orderedTaskIds.map((taskId) => byId.get(taskId)).filter((task): task is Task => Boolean(task));
    const missing = visibleTasks.filter((task) => !orderedTaskIds.includes(task.id));
    const merged = [...ordered, ...missing];

    if (!searchQuery.trim()) return merged;

    const query = searchQuery.trim().toLowerCase();
    return merged.filter(
      (task) =>
        task.title.toLowerCase().includes(query) ||
        (task.description ?? "").toLowerCase().includes(query) ||
        task.tags.some((tag) => tag.toLowerCase().includes(query))
    );
  }, [orderedTaskIds, searchQuery, visibleTasks]);

  const applyRemoteTasks = useCallback((incoming: Task[]) => {
    setTasks(incoming);
    tasksRef.current = incoming;
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
      applyRemoteTasks(remote);
      setSyncMessage(`已拉取 ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setSyncMessage(`拉取失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }, [applyRemoteTasks]);

  const commitTasks = useCallback(
    (next: Task[]) => {
      setTasks(next);
      tasksRef.current = next;
      void performSyncWithTasks(next);
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

  const addTask = useCallback(() => {
    if (!quickInput.trim()) return;
    const nextTask = buildQuickTask(createId(), quickInput);
    commitTasks([nextTask, ...tasksRef.current]);
    setQuickInput("");
  }, [commitTasks, quickInput]);

  const toggleDone = useCallback(
    (taskId: string) => {
      commitTasks(
        tasksRef.current.map((task) =>
          task.id === taskId
            ? makeTask({
                ...task,
                status: task.status === "done" ? "todo" : "done",
                updatedAt: new Date().toISOString()
              })
            : task
        )
      );
    },
    [commitTasks]
  );

  const archiveTask = useCallback(
    (taskId: string) => {
      commitTasks(
        tasksRef.current.map((task) =>
          task.id === taskId ? makeTask({ ...task, status: "archived", updatedAt: new Date().toISOString() }) : task
        )
      );
      if (editingTask?.id === taskId) {
        setEditingTask(null);
      }
    },
    [commitTasks, editingTask?.id]
  );

  const saveEditedTask = useCallback(
    (updated: Task) => {
      commitTasks(tasksRef.current.map((task) => (task.id === updated.id ? updated : task)));
      setEditingTask(null);
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
    quickInput,
    setQuickInput,
    editingTask,
    openTaskEditor: setEditingTask,
    closeTaskEditor: () => setEditingTask(null),
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
    scheduleView,
    blocksByDay,
    addTask,
    performSync: () => performSyncWithTasks(),
    toggleDone,
    archiveTask,
    saveEditedTask,
    importMarkdownFile,
    exportMarkdown: () => downloadMarkdown(visibleTasks),
    resetTimeTemplate: () => setTimeTemplate(DEFAULT_TIME_TEMPLATE),
    updateRange,
    addRange,
    removeRange
  };
};
