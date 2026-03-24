import SwiftUI

struct FocusCard: View {
  let task: Task
  let currentStepID: String?
  let onTap: () -> Void

  init(
    task: Task,
    currentStepID: String? = nil,
    onTap: @escaping () -> Void = {}
  ) {
    self.task = task
    self.currentStepID = currentStepID
    self.onTap = onTap
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 6) {
            Text("当前聚焦")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            Text(task.title)
              .font(.title3.weight(.bold))
              .foregroundStyle(.primary)
              .lineLimit(3)
          }
          Spacer()
          Circle()
            .fill(TaskDisplayFormatter.statusColor(for: task.status))
            .frame(width: 10, height: 10)
            .padding(.top, 4)
        }

        if let description = task.description {
          Text(description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        HStack(spacing: 8) {
          Text(TaskDisplayFormatter.statusLabel(for: task.status))
            .font(.caption.weight(.medium))
            .foregroundStyle(TaskDisplayFormatter.statusColor(for: task.status))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(TaskDisplayFormatter.statusColor(for: task.status).opacity(0.16), in: Capsule())

          Text("估时 \(task.estimatedMinutes) 分钟")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(NornTheme.pillSurface, in: Capsule())

          if let label = RelativeDueDateFormatter.label(for: task.dueAt) {
            Text(label)
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(NornTheme.pillSurface, in: Capsule())
          }
        }

        TaskStepPreviewView(
          task: task,
          currentStepID: currentStepID,
          style: .compact,
          accentColor: TaskDisplayFormatter.statusColor(for: task.status)
        )
        .padding(.top, task.steps.isEmpty ? 0 : 2)
    }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(NornTheme.cardSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
      )
      .shadow(color: NornTheme.shadow, radius: 16, y: 6)
    }
    .buttonStyle(.plain)
  }
}
