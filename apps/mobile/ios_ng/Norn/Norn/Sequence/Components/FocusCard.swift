import SwiftUI

struct FocusCard: View {
  let task: Task

  var body: some View {
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
          .fill(task.status.accentColor)
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
        Text(task.status.label)
          .font(.caption.weight(.medium))
          .foregroundStyle(task.status.accentColor)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(task.status.accentColor.opacity(0.10), in: Capsule())

        Text("估时 \(task.estimatedMinutes) 分钟")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.primary.opacity(0.06), in: Capsule())

        if let label = Formatters.dueLabel(for: task.dueAt) {
          Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
      }

      if !task.steps.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(task.steps) { step in
            HStack(spacing: 8) {
              Circle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 6, height: 6)
              Text(step.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
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
