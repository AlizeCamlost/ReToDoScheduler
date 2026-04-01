import SwiftUI

struct FocusCard: View {
  let task: Task
  let currentStepID: String?
  let onTap: () -> Void

  private var bundleMetadata: TaskBundleMetadata? {
    TaskBundleMetadata.metadata(for: task)
  }

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
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("当前聚焦")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            Text(task.title)
              .font(.headline.weight(.bold))
              .foregroundStyle(.primary)
              .lineLimit(3)
          }
          Spacer()
          Circle()
            .fill(TaskDisplayFormatter.statusColor(for: task.status))
            .frame(width: 8, height: 8)
            .padding(.top, 3)
        }

        if let description = task.description {
          Text(description)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        if let bundleMetadata {
          TaskBundleBadge(metadata: bundleMetadata)
        }

        HStack(spacing: 8) {
          Text(TaskDisplayFormatter.statusLabel(for: task.status))
            .font(.caption.weight(.medium))
            .foregroundStyle(TaskDisplayFormatter.statusColor(for: task.status))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(TaskDisplayFormatter.statusColor(for: task.status).opacity(0.16), in: Capsule())

          Text("估时 \(task.estimatedMinutes) 分钟")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(NornTheme.pillSurface, in: Capsule())

          if let label = RelativeDueDateFormatter.label(for: task.dueAt) {
            Text(label)
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 9)
              .padding(.vertical, 4)
              .background(NornTheme.pillSurface, in: Capsule())
          }
        }

        TaskStepPreviewView(
          task: task,
          currentStepID: currentStepID,
          style: .compact,
          accentColor: TaskDisplayFormatter.statusColor(for: task.status)
        )
        .padding(.top, task.steps.isEmpty ? 0 : 1)
    }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(NornTheme.cardSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
      )
      .shadow(color: NornTheme.shadow.opacity(0.7), radius: 10, y: 4)
    }
    .buttonStyle(.plain)
  }
}
