import Foundation

enum RelativeDueDateFormatter {
  static func label(
    for dueAt: Date?,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> String? {
    guard let dueAt else { return nil }

    let today = calendar.startOfDay(for: now)
    let dueDate = calendar.startOfDay(for: dueAt)
    let diff = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0

    if diff < 0 {
      return "逾期 \(abs(diff)) 天"
    }
    if diff == 0 {
      return "今天截止"
    }
    if diff == 1 {
      return "明天截止"
    }
    return "\(diff) 天后截止"
  }
}
