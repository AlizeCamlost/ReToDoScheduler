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
        focusSection
        queueSection(title: "接下来", tasks: nearTasks)
        queueSection(title: "较远", tasks: farTasks, dimmed: true)
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  @ViewBuilder
  private var focusSection: some View {
    if let task = focusedTask {
      FocusCard(task: task)
    } else {
      EmptyFocusCard()
    }
  }

  private func queueSection(title: String, tasks: [Task], dimmed: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: dimmed ? 10 : 12) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)

      VStack(spacing: dimmed ? 6 : 8) {
        if tasks.isEmpty {
          EmptyQueueCard(title: emptyQueueTitle(for: title), message: emptyQueueMessage(for: title), dimmed: dimmed)
        } else {
          ForEach(tasks) { task in
            TaskCard(task: task, dimmed: dimmed)
          }
        }
      }
    }
  }

  private func emptyQueueTitle(for sectionTitle: String) -> String {
    switch sectionTitle {
    case "接下来":
      return "暂无近期任务"
    case "较远":
      return "暂无远期任务"
    default:
      return "暂无任务"
    }
  }

  private func emptyQueueMessage(for sectionTitle: String) -> String {
    switch sectionTitle {
    case "接下来":
      return "新建任务后，近期需要处理的事项会按优先顺序排在这里。"
    case "较远":
      return "截止时间更远或暂不着急的事项，会沉到这个序列里。"
    default:
      return "新建任务后会出现在这里。"
    }
  }
}

#Preview {
  SequenceTab(tasks: Fixtures.tasks)
}

#Preview("Empty") {
  SequenceTab(tasks: [])
}

private struct EmptyFocusCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("当前聚焦")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text("暂无正在进行的任务")
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
        }
        Spacer()
        Circle()
          .fill(Color.primary.opacity(0.12))
          .frame(width: 10, height: 10)
          .padding(.top, 4)
      }

      Text("开始一个任务后，这里会显示你当前最值得投入的事项。")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        EmptyFocusPill(text: "无进行中任务")
        EmptyFocusPill(text: "等待新建或开始")
      }

      VStack(alignment: .leading, spacing: 6) {
        EmptyFocusHint(text: "从底部输入框快速添加")
        EmptyFocusHint(text: "或从任务池挑一个开始")
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.regularMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
  }
}

private struct EmptyFocusPill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.primary.opacity(0.06), in: Capsule())
  }
}

private struct EmptyFocusHint: View {
  let text: String

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.primary.opacity(0.18))
        .frame(width: 6, height: 6)
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct EmptyQueueCard: View {
  let title: String
  let message: String
  let dimmed: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Circle()
        .fill(Color.primary.opacity(dimmed ? 0.18 : 0.28))
        .frame(width: 8, height: 8)
        .padding(.top, 6)

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(message)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(dimmed ? Color.primary.opacity(0.03) : Color.primary.opacity(0.035))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(dimmed ? 0.035 : 0.05), lineWidth: 1)
    )
  }
}
