import { useEffect, useState } from "react";
import {
  Button,
  FlatList,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View
} from "react-native";
import type { Task } from "@retodo/core";
import { initializeDb } from "./src/db";
import { addTaskFromQuickInput, deleteTask, listTasks, toggleTaskDone } from "./src/taskService";

export default function App() {
  const [input, setInput] = useState("");
  const [tasks, setTasks] = useState<Task[]>([]);

  const refresh = async () => {
    const next = await listTasks();
    setTasks(next);
  };

  useEffect(() => {
    const boot = async () => {
      await initializeDb();
      await refresh();
    };
    void boot();
  }, []);

  const addTask = async () => {
    if (!input.trim()) return;
    await addTaskFromQuickInput(input.trim());
    setInput("");
    await refresh();
  };

  return (
    <SafeAreaView style={styles.page}>
      <Text style={styles.title}>ReToDoScheduler</Text>
      <Text style={styles.subtitle}>iPhone 离线任务列表（Phase 1）</Text>
      <View style={styles.row}>
        <TextInput
          style={styles.input}
          value={input}
          onChangeText={setInput}
          placeholder="输入任务，例如：周报 90分钟 #工作 专注"
        />
        <Button title="添加" onPress={() => void addTask()} />
      </View>
      <FlatList
        data={tasks}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <View style={styles.cardTop}>
              <View>
                <Text style={[styles.taskTitle, item.status === "done" && styles.done]}>{item.title}</Text>
                <Text style={styles.meta}>
                  估时 {item.estimatedMinutes}m | 最小拆分 {item.minChunkMinutes}m
                </Text>
              </View>
              <View style={styles.actions}>
                <TouchableOpacity onPress={() => void toggleTaskDone(item).then(refresh)}>
                  <Text style={styles.link}>{item.status === "done" ? "撤销" : "完成"}</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => void deleteTask(item.id).then(refresh)}>
                  <Text style={styles.linkDanger}>删除</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  page: {
    flex: 1,
    backgroundColor: "#f8f8f6",
    paddingHorizontal: 16,
    paddingTop: 12
  },
  title: {
    fontSize: 24,
    fontWeight: "700",
    color: "#111827"
  },
  subtitle: {
    fontSize: 12,
    color: "#6b7280",
    marginBottom: 12
  },
  row: {
    flexDirection: "row",
    gap: 8,
    marginBottom: 12
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    backgroundColor: "white",
    paddingHorizontal: 10,
    paddingVertical: 8
  },
  card: {
    backgroundColor: "white",
    borderWidth: 1,
    borderColor: "#e5e7eb",
    borderRadius: 10,
    padding: 10,
    marginBottom: 8
  },
  cardTop: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center"
  },
  taskTitle: {
    fontSize: 16,
    color: "#111827"
  },
  done: {
    textDecorationLine: "line-through",
    color: "#9ca3af"
  },
  meta: {
    fontSize: 12,
    color: "#6b7280"
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
