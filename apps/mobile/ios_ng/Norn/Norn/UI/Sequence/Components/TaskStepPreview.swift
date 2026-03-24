import SwiftUI

enum TaskStepPreviewStyle {
  case regular
  case compact
}

enum TaskStepPreviewResolver {
  static func currentStepInfo(for task: Task, currentStepID: String? = nil) -> (step: TaskStep, index: Int)? {
    guard !task.steps.isEmpty else {
      return nil
    }

    if let currentStepID, let index = task.steps.firstIndex(where: { $0.id == currentStepID }) {
      return (task.steps[index], index)
    }

    guard let index = task.currentStepIndex else {
      return nil
    }

    return (task.steps[index], index)
  }
}

struct TaskStepPreviewView: View {
  let task: Task
  var currentStepID: String? = nil
  var style: TaskStepPreviewStyle = .regular
  var accentColor: Color? = nil
  var isDimmed: Bool = false

  private var currentStepInfo: (step: TaskStep, index: Int)? {
    TaskStepPreviewResolver.currentStepInfo(for: task, currentStepID: currentStepID)
  }

  private var resolvedAccentColor: Color {
    (accentColor ?? TaskDisplayFormatter.statusColor(for: task.status))
      .opacity(isDimmed ? 0.6 : 1)
  }

  private var secondaryForeground: Color {
    isDimmed ? Color.secondary.opacity(0.72) : Color.secondary
  }

  var body: some View {
    if let currentStepInfo {
      switch style {
      case .regular:
        regularBody(currentStepInfo)
      case .compact:
        compactBody(currentStepInfo)
      }
    }
  }

  @ViewBuilder
  private func regularBody(_ currentStepInfo: (step: TaskStep, index: Int)) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("当前步骤")
          .font(.caption.weight(.semibold))
          .foregroundStyle(resolvedAccentColor)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(resolvedAccentColor.opacity(0.12), in: Capsule())

        Spacer(minLength: 8)

        Text("\(currentStepInfo.index + 1)/\(task.steps.count)")
          .font(.caption.weight(.medium))
          .foregroundStyle(resolvedAccentColor)
      }

      Text(currentStepInfo.step.title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isDimmed ? .secondary : .primary)
        .lineLimit(2)

      HStack(spacing: 8) {
        Text("串行步骤")
          .font(.caption)
          .foregroundStyle(secondaryForeground)
        Text("估时 \(currentStepInfo.step.estimatedMinutes) 分钟")
          .font(.caption)
          .foregroundStyle(secondaryForeground)
        Text("最小块 \(currentStepInfo.step.minChunkMinutes) 分钟")
          .font(.caption)
          .foregroundStyle(secondaryForeground)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.9)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(resolvedAccentColor.opacity(0.28), lineWidth: 1)
    )
  }

  @ViewBuilder
  private func compactBody(_ currentStepInfo: (step: TaskStep, index: Int)) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Circle()
        .fill(resolvedAccentColor)
        .frame(width: 8, height: 8)
        .padding(.top, 6)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("当前步骤")
            .font(.caption.weight(.semibold))
            .foregroundStyle(resolvedAccentColor)

          Spacer(minLength: 8)

          Text("\(currentStepInfo.index + 1)/\(task.steps.count)")
            .font(.caption.weight(.medium))
            .foregroundStyle(secondaryForeground)
        }

        Text(currentStepInfo.step.title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isDimmed ? .secondary : .primary)
          .lineLimit(2)

        Text("串行推进中")
          .font(.caption2)
          .foregroundStyle(secondaryForeground)
      }

      Spacer(minLength: 0)
    }
  }
}
