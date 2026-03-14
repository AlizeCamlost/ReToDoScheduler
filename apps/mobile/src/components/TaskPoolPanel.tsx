import { describeTaskMeta, type Task } from "@retodo/core";
import { FlatList, Text, TouchableOpacity, View } from "react-native";

interface TaskPoolPanelProps {
  tasks: Task[];
  onToggleDone: (task: Task) => void;
  onArchive: (taskId: string) => void;
  styles: any;
}

export default function TaskPoolPanel({ tasks, onToggleDone, onArchive, styles }: TaskPoolPanelProps) {
  return (
    <View style={styles.card}>
      <Text style={styles.sectionTitle}>任务池</Text>
      <FlatList
        data={tasks}
        keyExtractor={(item) => item.id}
        scrollEnabled={false}
        renderItem={({ item }) => (
          <View style={styles.taskCard}>
            <View style={styles.taskTop}>
              <View style={styles.taskContent}>
                <Text style={[styles.taskTitle, item.status === "done" && styles.done]}>{item.title}</Text>
                <Text style={styles.meta}>{describeTaskMeta(item)}</Text>
              </View>
              <View style={styles.actions}>
                <TouchableOpacity onPress={() => onToggleDone(item)}>
                  <Text style={styles.link}>{item.status === "done" ? "撤销" : "完成"}</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => onArchive(item.id)}>
                  <Text style={styles.linkDanger}>删除</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        )}
      />
    </View>
  );
}
