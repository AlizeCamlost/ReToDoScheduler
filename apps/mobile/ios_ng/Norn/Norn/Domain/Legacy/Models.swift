import Foundation
import SwiftUI

// MARK: - Navigation

enum AppTab: Int, CaseIterable {
  case sequence
  case schedule
  case taskPool
}

// MARK: - Task

enum TaskStatus: String {
  case todo
  case doing
  case done
  case archived

  var accentColor: Color {
    switch self {
    case .todo:     return Color(red: 0.19, green: 0.38, blue: 0.83)
    case .doing:    return Color(red: 0.94, green: 0.57, blue: 0.15)
    case .done:     return Color(red: 0.18, green: 0.61, blue: 0.39)
    case .archived: return .gray
    }
  }

  var label: String {
    switch self {
    case .todo:     return "待开始"
    case .doing:    return "进行中"
    case .done:     return "已完成"
    case .archived: return "已归档"
    }
  }
}

struct TaskStep: Identifiable, Hashable {
  let id: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dependsOnStepIDs: [String]
}

struct Task: Identifiable, Hashable {
  let id: String
  var title: String
  var description: String?
  var status: TaskStatus
  var estimatedMinutes: Int
  var dueAt: Date?
  var tags: [String]
  var steps: [TaskStep]
}

// MARK: - Formatters

enum Formatters {
  static func dueLabel(for dueAt: Date?) -> String? {
    guard let dueAt else { return nil }
    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date())
    let due = calendar.startOfDay(for: dueAt)
    let diff = calendar.dateComponents([.day], from: now, to: due).day ?? 0
    if diff < 0  { return "逾期 \(abs(diff)) 天" }
    if diff == 0 { return "今天截止" }
    if diff == 1 { return "明天截止" }
    return "\(diff) 天后截止"
  }
}

// MARK: - Preview Fixtures

enum Fixtures {
  static let tasks: [Task] = [
    Task(
      id: "task-1",
      title: "准备 TestFlight 发布",
      description: "整理截图、检查隐私说明并完成最后一轮自测。",
      status: .doing,
      estimatedMinutes: 90,
      dueAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
      tags: ["ios", "release"],
      steps: [
        TaskStep(id: "s1", title: "更新商店截图", estimatedMinutes: 30, minChunkMinutes: 15, dependsOnStepIDs: []),
        TaskStep(id: "s2", title: "核对隐私配置", estimatedMinutes: 20, minChunkMinutes: 10, dependsOnStepIDs: ["s1"])
      ]
    ),
    Task(
      id: "task-2",
      title: "排查同步报错",
      description: "检查 token、容器端口和 API 健康状态。",
      status: .todo,
      estimatedMinutes: 45,
      dueAt: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
      tags: ["backend"],
      steps: []
    ),
    Task(
      id: "task-3",
      title: "整理产品文档",
      description: "更新调度模型说明和数据结构图。",
      status: .todo,
      estimatedMinutes: 60,
      dueAt: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
      tags: ["docs"],
      steps: []
    ),
    Task(
      id: "task-4",
      title: "实现离线缓存逻辑",
      description: "使用 Core Data 做本地持久化，确保离线可读写。",
      status: .todo,
      estimatedMinutes: 120,
      dueAt: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
      tags: ["ios", "storage"],
      steps: [
        TaskStep(id: "s3", title: "设计 schema", estimatedMinutes: 30, minChunkMinutes: 15, dependsOnStepIDs: []),
        TaskStep(id: "s4", title: "实现读写层", estimatedMinutes: 60, minChunkMinutes: 30, dependsOnStepIDs: ["s3"]),
        TaskStep(id: "s5", title: "写集成测试", estimatedMinutes: 30, minChunkMinutes: 15, dependsOnStepIDs: ["s4"])
      ]
    ),
    Task(
      id: "task-5",
      title: "修复日历视图时区偏移",
      description: "跨时区场景下日期计算出现偏差。",
      status: .todo,
      estimatedMinutes: 30,
      dueAt: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
      tags: ["bug", "calendar"],
      steps: []
    ),
    Task(
      id: "task-6",
      title: "添加任务依赖关系 UI",
      description: nil,
      status: .todo,
      estimatedMinutes: 90,
      dueAt: Calendar.current.date(byAdding: .day, value: 6, to: Date()),
      tags: ["ios", "feature"],
      steps: []
    ),
    Task(
      id: "task-7",
      title: "对接后端任务 CRUD API",
      description: "完成 create / read / update / delete 四个端到端调通。",
      status: .todo,
      estimatedMinutes: 75,
      dueAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
      tags: ["backend", "api"],
      steps: []
    ),
    Task(
      id: "task-8",
      title: "重构同步模块",
      description: "拆分网络层与冲突解决逻辑，提高可测试性。",
      status: .todo,
      estimatedMinutes: 120,
      dueAt: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
      tags: ["backend", "refactor"],
      steps: []
    ),
    Task(
      id: "task-9",
      title: "调度器价值模型调优",
      description: "调整 rewardOnTime / penaltyMissed 参数，观察排序变化。",
      status: .todo,
      estimatedMinutes: 60,
      dueAt: Calendar.current.date(byAdding: .day, value: 21, to: Date()),
      tags: ["scheduler"],
      steps: []
    ),
    Task(
      id: "task-10",
      title: "阅读 WWDC 25 Session 笔记",
      description: nil,
      status: .todo,
      estimatedMinutes: 40,
      dueAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
      tags: ["learning"],
      steps: []
    ),
    Task(
      id: "task-11",
      title: "评估 CloudKit 替代方案",
      description: "对比自建同步和 CloudKit 的维护成本与功能覆盖。",
      status: .todo,
      estimatedMinutes: 45,
      dueAt: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
      tags: ["research"],
      steps: []
    ),
    Task(
      id: "task-12",
      title: "学习 Swift Concurrency 高级用法",
      description: nil,
      status: .todo,
      estimatedMinutes: 90,
      dueAt: Calendar.current.date(byAdding: .day, value: 60, to: Date()),
      tags: ["learning"],
      steps: []
    )
  ]
}
