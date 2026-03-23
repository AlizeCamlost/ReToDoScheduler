import SwiftUI

struct TaskDetailSheet: View {
  let task: Task
  let onToggleCompletion: () -> Void
  let onArchive: () -> Void
  let onEdit: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var archiveConfirmationPresented = false

  private var actionTitle: String {
    task.status == .done ? "恢复待办" : "标记完成"
  }

  private var completionActionSymbol: String {
    task.status == .done ? "arrow.uturn.backward.circle" : "checkmark.circle"
  }

  var body: some View {
    NavigationStack {
      ZStack {
        NornScreenBackground()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 24) {
            headerSection
            metaSection
            if let description = task.description, !description.isEmpty {
              descriptionSection(description)
            }
            if !task.steps.isEmpty {
              stepsSection
            }
            if !task.tags.isEmpty {
              tagsSection
            }
            rawInputSection
            actionSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 32)
        }
      }
      .navigationTitle("任务详情")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("关闭") {
            dismiss()
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("编辑", action: onEdit)
        }
      }
    }
    .confirmationDialog(
      "归档这个任务？",
      isPresented: $archiveConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("归档任务", role: .destructive, action: onArchive)
      Button("取消", role: .cancel) {}
    } message: {
      Text("归档后任务会从当前视图隐藏，但仍保留历史记录。")
    }
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(task.title)
        .font(.title2.weight(.bold))
        .foregroundStyle(.primary)

      HStack(spacing: 10) {
        DetailPill(
          text: TaskDisplayFormatter.statusLabel(for: task.status),
          foreground: TaskDisplayFormatter.statusColor(for: task.status),
          background: TaskDisplayFormatter.statusColor(for: task.status).opacity(0.12)
        )
        DetailPill(
          text: "估时 \(task.estimatedMinutes) 分钟",
          foreground: .secondary,
          background: NornTheme.pillSurface
        )
        DetailPill(
          text: "最小块 \(task.minChunkMinutes) 分钟",
          foreground: .secondary,
          background: NornTheme.pillSurface
        )
      }
    }
  }

  private var metaSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: "截止", value: RelativeDueDateFormatter.label(for: task.dueAt) ?? "未设置")
      DetailRow(label: "价值", value: "按时 +\(task.scheduleValue.rewardOnTime) / 逾期 -\(task.scheduleValue.penaltyMissed)")
      DetailRow(label: "依赖", value: task.dependsOnTaskIDs.isEmpty ? "无" : task.dependsOnTaskIDs.joined(separator: ", "))
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }

  private func descriptionSection(_ description: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("描述")
      Text(description)
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var stepsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionTitle("步骤")
      VStack(alignment: .leading, spacing: 10) {
        ForEach(task.steps) { step in
          VStack(alignment: .leading, spacing: 4) {
            Text(step.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
            Text("估时 \(step.estimatedMinutes) 分钟 | 最小块 \(step.minChunkMinutes) 分钟")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(NornTheme.cardSurfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
      }
    }
  }

  private var tagsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("标签")
      Text(task.tags.map { "#\($0)" }.joined(separator: " "))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  private var rawInputSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("原始输入")
      Text(task.rawInput)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NornTheme.cardSurfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private var actionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("操作")

      VStack(spacing: 0) {
        Button(action: onToggleCompletion) {
          DetailActionRow(
            title: actionTitle,
            systemImage: completionActionSymbol,
            tint: .primary
          )
        }
        .buttonStyle(.plain)

        Divider()
          .overlay(NornTheme.divider)
          .padding(.leading, 48)

        Button(role: .destructive) {
          archiveConfirmationPresented = true
        } label: {
          DetailActionRow(
            title: "归档任务",
            systemImage: "archivebox.fill",
            tint: .red
          )
        }
        .buttonStyle(.plain)
      }
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(NornTheme.cardSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
      )
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
  }
}

private struct DetailRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 56, alignment: .leading)
      Text(value)
        .font(.subheadline)
        .foregroundStyle(.primary)
      Spacer()
    }
  }
}

private struct DetailPill: View {
  let text: String
  let foreground: Color
  let background: Color

  var body: some View {
    Text(text)
      .font(.caption.weight(.medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(background, in: Capsule())
  }
}

private struct DetailActionRow: View {
  let title: String
  let systemImage: String
  let tint: Color

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.body.weight(.semibold))
      Text(title)
        .font(.body)
      Spacer()
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .foregroundStyle(tint)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .contentShape(Rectangle())
  }
}

#Preview {
  TaskDetailSheet(
    task: NornPreviewFixtures.tasks[0],
    onToggleCompletion: {},
    onArchive: {},
    onEdit: {}
  )
}
