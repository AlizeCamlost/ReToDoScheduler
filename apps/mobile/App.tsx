import { useEffect, useMemo, useRef, useState } from "react";
import {
  Button,
  FlatList,
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
  createDefaultComparator,
  refreshSchedule,
  type Task
} from "@retodo/core";
import { initializeDb } from "./src/db";
import { syncTasksWithServer } from "./src/syncService";
import { addTaskFromQuickInput, archiveTask, listTasks, toggleTaskDone } from "./src/taskService";

const HORIZON_OPTIONS = [
  { label: "1天", days: 1 },
  { label: "7天", days: 7 },
  { label: "21天", days: 21 }
] as const;

const addDays = (source: Date, days: number): Date => {
  const next = new Date(source);
  next.setDate(next.getDate() + days);
  return next;
};

const formatClock = (source: string): string =>
  new Date(source).toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });

const formatDay = (source: string): string =>
  new Date(source).toLocaleDateString("zh-CN", { month: "numeric", day: "numeric", weekday: "short" });

export default function App() {
  const [input, setInput] = useState("");
  const [tasks, setTasks] = useState<Task[]>([]);
  const [syncMessage, setSyncMessage] = useState("未同步");
  const [isSyncing, setIsSyncing] = useState(false);
  const [horizonDays, setHorizonDays] = useState<number>(7);

  const syncInFlightRef = useRef(false);

  const visibleTasks = useMemo(() => tasks.filter((task) => task.status !== "archived"), [tasks]);
  const scheduleView = useMemo(
    () => refreshSchedule(visibleTasks, DEFAULT_TIME_TEMPLATE, new Date(), addDays(new Date(), horizonDays), createDefaultComparator()),
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

        <View style={styles.card}>
          <Text style={styles.sectionTitle}>观察窗口</Text>
          <View style={styles.tabRow}>
            {HORIZON_OPTIONS.map((option) => (
              <TouchableOpacity
                key={option.days}
                onPress={() => setHorizonDays(option.days)}
                style={[styles.tab, horizonDays === option.days && styles.tabActive]}
              >
                <Text style={[styles.tabText, horizonDays === option.days && styles.tabTextActive]}>{option.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {scheduleView.warnings.length > 0 && (
            <View style={styles.warningList}>
              {scheduleView.warnings.map((warning, index) => (
                <Text key={`${warning.code}-${index}`} style={[styles.warningItem, warning.severity === "danger" && styles.warningDanger]}>
                  {warning.message}
                </Text>
              ))}
            </View>
          )}

          <Text style={styles.sectionTitle}>时间块</Text>
          {scheduleView.blocks.length === 0 ? (
            <Text style={styles.helper}>当前窗口内还没有排入时间块。</Text>
          ) : (
            scheduleView.blocks.map((block) => {
              const step = scheduleView.orderedSteps.find((item) => item.stepId === block.stepId);
              return (
                <View key={block.id} style={styles.blockCard}>
                  <Text style={styles.blockDay}>{formatDay(block.startAt)}</Text>
                  <Text style={styles.blockTime}>
                    {formatClock(block.startAt)} - {formatClock(block.endAt)}
                  </Text>
                  <Text style={styles.blockTitle}>
                    {step?.taskTitle ?? "任务"} / {step?.title ?? "步骤"}
                  </Text>
                </View>
              );
            })
          )}

          <Text style={styles.sectionTitle}>任务序列</Text>
          {scheduleView.orderedSteps.map((step) => (
            <View key={step.stepId} style={styles.orderedCard}>
              <Text style={styles.orderedTitle}>
                {step.taskTitle}
                {step.title !== step.taskTitle ? ` / ${step.title}` : ""}
              </Text>
              <Text style={styles.orderedMeta}>
                已排 {step.plannedMinutes}m | 剩余 {step.remainingMinutes}m
                {step.dueAt ? ` | DDL ${step.dueAt.slice(0, 10)}` : ""}
              </Text>
            </View>
          ))}
        </View>

        <View style={styles.card}>
          <Text style={styles.sectionTitle}>任务池</Text>
          <FlatList
            data={visibleTasks}
            keyExtractor={(item) => item.id}
            scrollEnabled={false}
            renderItem={({ item }) => (
              <View style={styles.taskCard}>
                <View style={styles.taskTop}>
                  <View style={styles.taskContent}>
                    <Text style={[styles.taskTitle, item.status === "done" && styles.done]}>{item.title}</Text>
                    <Text style={styles.meta}>
                      估时 {item.estimatedMinutes}m | 最小块 {item.minChunkMinutes}m | 奖励 {item.scheduleValue.rewardOnTime} | 损失 {item.scheduleValue.penaltyMissed}
                    </Text>
                  </View>
                  <View style={styles.actions}>
                    <TouchableOpacity
                      onPress={() =>
                        void toggleTaskDone(item)
                          .then(refresh)
                          .then(() => syncNow())
                      }
                    >
                      <Text style={styles.link}>{item.status === "done" ? "撤销" : "完成"}</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      onPress={() =>
                        void archiveTask(item.id)
                          .then(refresh)
                          .then(() => syncNow())
                      }
                    >
                      <Text style={styles.linkDanger}>删除</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            )}
          />
        </View>
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
