import SwiftUI

struct TaskCard: View {
  let task: Task
  let dimmed: Bool
  let currentStepID: String?
  let onTap: () -> Void

  init(
    task: Task,
    dimmed: Bool = false,
    currentStepID: String? = nil,
    onTap: @escaping () -> Void = {}
  ) {
    self.task = task
    self.dimmed = dimmed
    self.currentStepID = currentStepID
    self.onTap = onTap
  }

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 14) {
        Circle()
          .fill(TaskDisplayFormatter.statusColor(for: task.status).opacity(dimmed ? 0.4 : 0.85))
          .frame(width: 8, height: 8)
          .padding(.top, 6)

        VStack(alignment: .leading, spacing: 6) {
          Text(task.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(dimmed ? .secondary : .primary)
            .lineLimit(2)

          HStack(spacing: 6) {
            if let label = RelativeDueDateFormatter.label(for: task.dueAt) {
              Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if !task.tags.isEmpty {
              Text(task.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }

          TaskStepPreviewView(
            task: task,
            currentStepID: currentStepID,
            style: .compact,
            accentColor: TaskDisplayFormatter.statusColor(for: task.status),
            isDimmed: dimmed
          )
        }

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(dimmed ? NornTheme.cardSurfaceMuted : NornTheme.cardSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(dimmed ? NornTheme.border : NornTheme.borderStrong, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}
