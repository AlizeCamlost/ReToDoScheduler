import SwiftUI

struct SequenceTab: View {
  let tasks: [Task]

  private var focusedTask: Task? {
    tasks.first { $0.status == .doing }
  }

  private var queueTasks: [Task] {
    tasks.filter { $0.status == .todo }
  }

  private let nearHorizon = 7 // days

  private var nearTasks: [Task] {
    queueTasks.filter { task in
      guard let due = task.dueAt else { return true }
      let diff = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
      return diff <= nearHorizon
    }
  }

  private var farTasks: [Task] {
    queueTasks.filter { task in
      guard let due = task.dueAt else { return false }
      let diff = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
      return diff > nearHorizon
    }
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 28) {

        if let task = focusedTask {
          FocusCard(task: task)
        }

        if !nearTasks.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("接下来")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)

            VStack(spacing: 8) {
              ForEach(nearTasks) { task in
                TaskCard(task: task)
              }
            }
          }
        }

        if !farTasks.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("较远")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)

            VStack(spacing: 6) {
              ForEach(farTasks) { task in
                TaskCard(task: task, dimmed: true)
              }
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
  }
}

#Preview {
  SequenceTab(tasks: Fixtures.tasks)
}
