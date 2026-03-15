import Foundation

enum AppFormatters {
  static let clock: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  static let day: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日 EEE"
    return formatter
  }()

  static func formatClock(_ date: Date) -> String {
    clock.string(from: date)
  }

  static func formatDay(_ date: Date) -> String {
    day.string(from: date)
  }

  static func taskMeta(_ task: Task) -> String {
    "估时 \(task.estimatedMinutes)m | 最小块 \(task.minChunkMinutes)m | 奖励 \(task.scheduleValue.rewardOnTime) | 损失 \(task.scheduleValue.penaltyMissed)"
  }

  static func dueLabel(for dueAt: Date?) -> String? {
    guard let dueAt else { return nil }

    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date())
    let due = calendar.startOfDay(for: dueAt)
    let diffDays = calendar.dateComponents([.day], from: now, to: due).day ?? 0

    if diffDays < 0 { return "逾期 \(abs(diffDays)) 天" }
    if diffDays == 0 { return "今天截止" }
    if diffDays == 1 { return "明天截止" }
    return "\(diffDays) 天后截止"
  }
}
