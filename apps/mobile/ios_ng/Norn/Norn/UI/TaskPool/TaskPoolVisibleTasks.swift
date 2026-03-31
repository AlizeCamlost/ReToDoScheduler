import Foundation

enum TaskPoolVisibleTasks {
  static func filtered(_ tasks: [Task], hideCompleted: Bool) -> [Task] {
    tasks.filter { task in
      guard task.status != .archived else {
        return false
      }
      return !hideCompleted || task.status != .done
    }
  }
}
