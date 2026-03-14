import { useEffect, useMemo, useRef, useState } from "react";
import {
  Button,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View
} from "react-native";
import {
  DEFAULT_TIME_TEMPLATE,
  buildSchedulePresentation,
  type Task
} from "@retodo/core";
import SchedulePanel from "./src/components/SchedulePanel";
import TaskPoolPanel from "./src/components/TaskPoolPanel";
import { initializeDb } from "./src/db";
import { syncTasksWithServer } from "./src/syncService";
import { addTaskFromQuickInput, archiveTask, listTasks, toggleTaskDone } from "./src/taskService";

export default function App() {
  const [input, setInput] = useState("");
  const [tasks, setTasks] = useState<Task[]>([]);
  const [syncMessage, setSyncMessage] = useState("未同步");
  const [isSyncing, setIsSyncing] = useState(false);
  const [horizonDays, setHorizonDays] = useState<number>(7);

  const syncInFlightRef = useRef(false);

  const visibleTasks = useMemo(() => tasks.filter((task) => task.status !== "archived"), [tasks]);
  const { scheduleView } = useMemo(
    () => buildSchedulePresentation(visibleTasks, DEFAULT_TIME_TEMPLATE, horizonDays),
    [visibleTasks, horizonDays]
  );

  const refresh = async () => {
    const next = await listTasks();
    setTasks(next);
  };

  const syncNow = async () => {
    if (syncInFlightRef.current) return;

    syncInFlightRef.current = true;
    setIsSyncing(true);

    try {
      const result = await syncTasksWithServer();
      await refresh();
      setSyncMessage(`已同步 ${result.synced} 项，${new Date().toLocaleTimeString()}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setSyncMessage(`同步失败: ${message}`);
    } finally {
      syncInFlightRef.current = false;
      setIsSyncing(false);
    }
  };

  useEffect(() => {
    const boot = async () => {
      await initializeDb();
      await refresh();
      await syncNow();
    };
    void boot();
  }, []);

  useEffect(() => {
    const timer = setInterval(() => {
      void syncNow();
    }, 7000);

    return () => clearInterval(timer);
  }, []);

  const addTask = async () => {
    if (!input.trim()) return;
    await addTaskFromQuickInput(input.trim());
    setInput("");
    await refresh();
    await syncNow();
  };

  return (
    <SafeAreaView style={styles.page}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.title}>任务池</Text>
        <Text style={styles.subtitle}>动态调度视图基于当前任务池和固定时间模板实时计算</Text>

        <View style={styles.card}>
          <View style={styles.row}>
            <TextInput
              style={styles.input}
              value={input}
              onChangeText={setInput}
              placeholder="输入任务，例如：周报 90分钟 明天"
            />
            <Button title="添加" onPress={() => void addTask()} />
          </View>
          <Button title={isSyncing ? "同步中" : "立即同步"} onPress={() => void syncNow()} />
          <Text style={styles.syncLabel}>{syncMessage}</Text>
        </View>

        <SchedulePanel horizonDays={horizonDays} onChangeHorizon={setHorizonDays} scheduleView={scheduleView} styles={styles} />

        <TaskPoolPanel
          tasks={visibleTasks}
          styles={styles}
          onToggleDone={(task) =>
            void toggleTaskDone(task)
              .then(refresh)
              .then(() => syncNow())
          }
          onArchive={(taskId) =>
            void archiveTask(taskId)
              .then(refresh)
              .then(() => syncNow())
          }
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  page: {
    flex: 1,
    backgroundColor: "#f5f5f0"
  },
  scrollContent: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 24,
    gap: 12
  },
  title: {
    fontSize: 24,
    fontWeight: "700",
    color: "#1f2937"
  },
  subtitle: {
    fontSize: 12,
    color: "#6b7280"
  },
  card: {
    backgroundColor: "#ffffff",
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#e5e7eb",
    padding: 12,
    gap: 10
  },
  row: {
    flexDirection: "row",
    gap: 8,
    alignItems: "center"
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
    backgroundColor: "white"
  },
  syncLabel: {
    fontSize: 12,
    color: "#4b5563"
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: "600",
    color: "#111827"
  },
  tabRow: {
    flexDirection: "row",
    gap: 8
  },
  tab: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "#d1d5db"
  },
  tabActive: {
    backgroundColor: "#111827",
    borderColor: "#111827"
  },
  tabText: {
    color: "#4b5563",
    fontSize: 12
  },
  tabTextActive: {
    color: "#ffffff"
  },
  warningList: {
    gap: 8
  },
  warningItem: {
    backgroundColor: "#fff7ed",
    color: "#9a3412",
    borderRadius: 8,
    padding: 10,
    fontSize: 12
  },
  warningDanger: {
    backgroundColor: "#fef2f2",
    color: "#b91c1c"
  },
  helper: {
    fontSize: 12,
    color: "#6b7280"
  },
  blockCard: {
    borderWidth: 1,
    borderColor: "#e5e7eb",
    borderRadius: 10,
    padding: 10,
    gap: 2
  },
  blockDay: {
    fontSize: 12,
    color: "#6b7280"
  },
  blockTime: {
    fontSize: 12,
    color: "#374151"
  },
  blockTitle: {
    fontSize: 14,
    color: "#111827"
  },
  orderedCard: {
    borderWidth: 1,
    borderColor: "#e5e7eb",
    borderRadius: 10,
    padding: 10
  },
  orderedTitle: {
    fontSize: 14,
    color: "#111827"
  },
  orderedMeta: {
    fontSize: 12,
    color: "#6b7280",
    marginTop: 4
  },
  taskCard: {
    borderWidth: 1,
    borderColor: "#e5e7eb",
    borderRadius: 10,
    padding: 10,
    marginBottom: 8
  },
  taskTop: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 12
  },
  taskContent: {
    flex: 1
  },
  taskTitle: {
    fontSize: 15,
    color: "#111827"
  },
  done: {
    textDecorationLine: "line-through",
    color: "#9ca3af"
  },
  meta: {
    fontSize: 12,
    color: "#6b7280",
    marginTop: 4
  },
  actions: {
    flexDirection: "row",
    gap: 10
  },
  link: {
    color: "#2563eb"
  },
  linkDanger: {
    color: "#dc2626"
  }
});
