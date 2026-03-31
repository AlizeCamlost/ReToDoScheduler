import SwiftUI

struct TaskPoolCanvasNodePresentation: Identifiable {
  enum Accent {
    case directory
    case inbox
    case task(TaskStatus)
  }

  var id: String {
    "\(nodeKind.rawValue):\(nodeID)"
  }

  let nodeID: String
  let nodeKind: TaskPoolCanvasNodeLayout.NodeKind
  let title: String
  let subtitle: String
  let detail: String?
  let position: CGPoint
  let isCollapsed: Bool
  let accent: Accent
  let task: Task?
}

struct TaskPoolCanvasNodeCard: View {
  let node: TaskPoolCanvasNodePresentation
  let onToggleCollapse: () -> Void
  let onTap: () -> Void

  private var accentColor: Color {
    switch node.accent {
    case .directory:
      return .orange
    case .inbox:
      return .blue
    case .task(let status):
      return TaskDisplayFormatter.statusColor(for: status)
    }
  }

  private var symbolName: String {
    switch node.nodeKind {
    case .directory:
      switch node.accent {
      case .inbox:
        return "tray.full.fill"
      default:
        return "folder.fill"
      }
    case .task:
      return "checklist"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: symbolName)
          .font(.headline)
          .foregroundStyle(accentColor)
          .frame(width: 24, height: 24)

        VStack(alignment: .leading, spacing: 4) {
          Text(node.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

          Text(node.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer(minLength: 8)

        Button {
          onToggleCollapse()
        } label: {
          Image(systemName: node.isCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      if !node.isCollapsed {
        if let detail = node.detail {
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let task = node.task {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
              if let dueLabel = RelativeDueDateFormatter.label(for: task.dueAt) {
                Text(dueLabel)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.secondary)
              }

              if !task.tags.isEmpty {
                Text(task.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
                  .lineLimit(1)
              }
            }

            TaskStepPreviewView(
              task: task,
              currentStepID: task.currentStep?.id,
              style: .compact,
              accentColor: accentColor,
              isDimmed: task.status == .done
            )
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(width: node.isCollapsed ? 220 : 260, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(accentColor.opacity(0.18), lineWidth: 1.5)
    )
    .shadow(color: NornTheme.shadow.opacity(0.10), radius: 16, y: 6)
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .onTapGesture(perform: onTap)
  }
}
