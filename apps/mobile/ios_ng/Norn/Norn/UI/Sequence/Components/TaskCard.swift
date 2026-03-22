import SwiftUI

struct TaskCard: View {
  let task: Task
  let dimmed: Bool

  init(task: Task, dimmed: Bool = false) {
    self.task = task
    self.dimmed = dimmed
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Circle()
        .fill(task.status.accentColor.opacity(dimmed ? 0.4 : 0.85))
        .frame(width: 8, height: 8)
        .padding(.top, 6)

      VStack(alignment: .leading, spacing: 6) {
        Text(task.title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(dimmed ? .secondary : .primary)
          .lineLimit(2)

        HStack(spacing: 6) {
          if let label = Formatters.dueLabel(for: task.dueAt) {
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
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(dimmed ? Color.primary.opacity(0.04) : Color.white.opacity(0.55))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(dimmed ? 0.04 : 0.07), lineWidth: 1)
    )
  }
}
