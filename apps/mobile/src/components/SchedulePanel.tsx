import {
  HORIZON_OPTIONS,
  formatScheduleClock,
  formatScheduleDay,
  type ScheduleView
} from "@retodo/core";
import { Text, TouchableOpacity, View } from "react-native";

interface SchedulePanelProps {
  horizonDays: number;
  onChangeHorizon: (days: number) => void;
  scheduleView: ScheduleView;
  styles: any;
}

export default function SchedulePanel({
  horizonDays,
  onChangeHorizon,
  scheduleView,
  styles
}: SchedulePanelProps) {
  return (
    <View style={styles.card}>
      <Text style={styles.sectionTitle}>观察窗口</Text>
      <View style={styles.tabRow}>
        {HORIZON_OPTIONS.filter((option) => option.days <= 21).map((option) => (
          <TouchableOpacity
            key={option.days}
            onPress={() => onChangeHorizon(option.days)}
            style={[styles.tab, horizonDays === option.days && styles.tabActive]}
          >
            <Text style={[styles.tabText, horizonDays === option.days && styles.tabTextActive]}>{option.compactLabel}</Text>
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
              <Text style={styles.blockDay}>{formatScheduleDay(block.startAt)}</Text>
              <Text style={styles.blockTime}>
                {formatScheduleClock(block.startAt)} - {formatScheduleClock(block.endAt)}
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
  );
}
