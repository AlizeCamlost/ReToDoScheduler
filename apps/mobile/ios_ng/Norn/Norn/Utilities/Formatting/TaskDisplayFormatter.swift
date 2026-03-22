import Foundation
import SwiftUI

enum TaskDisplayFormatter {
  static func statusLabel(for status: TaskStatus) -> String {
    switch status {
    case .todo:
      return "待开始"
    case .doing:
      return "进行中"
    case .done:
      return "已完成"
    case .archived:
      return "已归档"
    }
  }

  static func statusColor(for status: TaskStatus) -> Color {
    switch status {
    case .todo:
      return Color(red: 0.19, green: 0.38, blue: 0.83)
    case .doing:
      return Color(red: 0.94, green: 0.57, blue: 0.15)
    case .done:
      return Color(red: 0.18, green: 0.61, blue: 0.39)
    case .archived:
      return .gray
    }
  }
}
