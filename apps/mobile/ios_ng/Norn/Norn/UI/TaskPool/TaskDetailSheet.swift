import SwiftUI

struct TaskDetailSheet: View {
  let task: Task
  let onToggleCompletion: () -> Void
  let onArchive: () -> Void
  let onEdit: () -> Void
  let onPromoteToDoing: () -> Void
  let onAddStep: (String) -> Void
  let onCurrentStepTap: (TaskStep) -> Void
  let currentStepID: String?

  @Environment(\.dismiss) private var dismiss
  @State private var archiveConfirmationPresented = false
  @State private var newStepTitle = ""

  init(
    task: Task,
    onToggleCompletion: @escaping () -> Void,
    onArchive: @escaping () -> Void,
    onEdit: @escaping () -> Void,
    onPromoteToDoing: @escaping () -> Void = {},
    onAddStep: @escaping (String) -> Void = { _ in },
    currentStepID: String? = nil,
    onCurrentStepTap: @escaping (TaskStep) -> Void = { _ in }
  ) {
    self.task = task
    self.onToggleCompletion = onToggleCompletion
    self.onArchive = onArchive
    self.onEdit = onEdit
    self.onPromoteToDoing = onPromoteToDoing
    self.onAddStep = onAddStep
    self.currentStepID = currentStepID
    self.onCurrentStepTap = onCurrentStepTap
  }

  private var currentStepInfo: (step: TaskStep, index: Int)? {
    TaskStepPreviewResolver.currentStepInfo(for: task, currentStepID: currentStepID)
  }

  private var actionTitle: String {
    task.status == .done ? "恢复待办" : "标记完成"
  }

  private var completionActionSymbol: String {
    task.status == .done ? "arrow.uturn.backward.circle" : "checkmark.circle"
  }

  private var promoteActionTitle: String {
    task.status == .doing ? "当前已在进行中" : "切到进行中"
  }

  private var promoteActionSubtitle: String {
    task.status == .doing ? "保持执行态，不必进入编辑器" : "把任务直接切换到进行中"
  }

  var body: some View {
    NavigationStack {
      ZStack {
        NornScreenBackground()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 24) {
            headerSection
            quickActionSection
            metaSection

            if let description = task.description, !description.isEmpty {
              descriptionSection(description)
            }

            if !task.steps.isEmpty {
              if currentStepInfo != nil {
                currentStepSection
              }
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
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
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

  private var quickActionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("快捷操作")

      VStack(spacing: 0) {
        Button(action: onPromoteToDoing) {
          DetailActionRow(
            title: promoteActionTitle,
            subtitle: promoteActionSubtitle,
            systemImage: "play.circle",
            tint: .primary
          )
        }
        .buttonStyle(.plain)

        Divider()
          .overlay(NornTheme.divider)
          .padding(.leading, 48)

        DetailInlineStepComposer(
          title: $newStepTitle,
          onSubmit: submitNewStep
        )

        if let currentStepInfo {
          Divider()
            .overlay(NornTheme.divider)
            .padding(.leading, 48)

          Button {
            onCurrentStepTap(currentStepInfo.step)
          } label: {
            DetailActionRow(
              title: "推进当前步骤",
              subtitle: currentStepInfo.step.title,
              systemImage: "checkmark.circle",
              tint: .primary
            )
          }
          .buttonStyle(.plain)
        }
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

  private var metaSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: "截止", value: RelativeDueDateFormatter.label(for: task.dueAt) ?? "未设置")
      DetailRow(label: "价值", value: "按时 +\(task.scheduleValue.rewardOnTime) / 逾期 -\(task.scheduleValue.penaltyMissed)")
      DetailRow(label: "依赖", value: task.dependsOnTaskIDs.isEmpty ? "无" : task.dependsOnTaskIDs.joined(separator: ", "))
      DetailRow(label: "子任务", value: task.steps.isEmpty ? "无" : "\(task.steps.count) 步")
      if let currentStepInfo {
        DetailRow(label: "当前", value: currentStepInfo.step.title)
      }
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

  private var currentStepSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionTitle("当前步骤")

      TaskStepPreviewView(
        task: task,
        currentStepID: currentStepID,
        style: .regular,
        accentColor: TaskDisplayFormatter.statusColor(for: task.status)
      )
    }
  }

  private var stepsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionTitle("子任务串")

      VStack(spacing: 0) {
        ForEach(Array(task.steps.enumerated()), id: \.element.id) { index, step in
          let progressState = task.stepProgressState(for: step.id) ?? .upcoming
          let isCurrent = progressState == .current

          Button {
            guard isCurrent else { return }
            onCurrentStepTap(step)
          } label: {
            TaskDetailStepRow(
              step: step,
              index: index,
              totalCount: task.steps.count,
              progressState: progressState
            )
          }
          .buttonStyle(.plain)
          .disabled(!isCurrent)

          if index < task.steps.count - 1 {
            Divider()
              .overlay(NornTheme.divider)
              .padding(.leading, 52)
          }
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(NornTheme.cardSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
      )
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
            subtitle: task.status == .done ? "把任务恢复回待办" : "完成后会退出当前视图",
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
            subtitle: "保留历史记录，但从当前视图隐藏",
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

  private func submitNewStep() {
    let trimmedTitle = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }
    onAddStep(trimmedTitle)
    newStepTitle = ""
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
  let subtitle: String?
  let systemImage: String
  let tint: Color

  init(title: String, subtitle: String? = nil, systemImage: String, tint: Color) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.tint = tint
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.body.weight(.semibold))
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.body)

        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
        .padding(.top, 3)
    }
    .foregroundStyle(tint)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .contentShape(Rectangle())
  }
}

private struct TaskDetailStepRow: View {
  let step: TaskStep
  let index: Int
  let totalCount: Int
  let progressState: Task.StepProgressState

  private var accentColor: Color {
    switch progressState {
    case .completed:
      return TaskDisplayFormatter.statusColor(for: .done)
    case .current:
      return TaskDisplayFormatter.statusColor(for: .doing)
    case .upcoming:
      return .secondary
    }
  }

  private var isCurrent: Bool {
    progressState == .current
  }

  private var isCompleted: Bool {
    progressState == .completed
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(isCurrent || isCompleted ? accentColor.opacity(0.14) : NornTheme.pillSurface)
          .frame(width: 28, height: 28)

        if isCompleted {
          Image(systemName: "checkmark")
            .font(.caption.weight(.bold))
            .foregroundStyle(accentColor)
        } else {
          Text("\(index + 1)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isCurrent ? accentColor : .secondary)
        }
      }
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(step.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isCurrent ? .primary : (isCompleted ? .secondary : .secondary))
            .strikethrough(isCompleted, color: .secondary)
            .lineLimit(2)

          if isCurrent {
            Text("当前")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(accentColor)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(accentColor.opacity(0.12), in: Capsule())
          } else if isCompleted {
            Text("已完成")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(accentColor)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(accentColor.opacity(0.12), in: Capsule())
          }
        }

        Text("估时 \(step.estimatedMinutes) 分钟 · 最小块 \(step.minChunkMinutes) 分钟")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 4) {
        Text("\(index + 1)/\(totalCount)")
          .font(.caption.weight(.medium))
          .foregroundStyle(isCurrent || isCompleted ? accentColor : Color.secondary.opacity(0.6))

        if isCurrent {
          Text("点按推进")
            .font(.caption2)
            .foregroundStyle(.secondary)
        } else if isCompleted {
          Text("已推进")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.top, 2)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background((isCurrent || isCompleted) ? accentColor.opacity(0.05) : Color.clear)
    .contentShape(Rectangle())
  }
}

private struct DetailInlineStepComposer: View {
  @Binding var title: String
  let onSubmit: () -> Void

  private var submitEnabled: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Image(systemName: "plus.circle")
          .font(.body.weight(.semibold))
          .foregroundStyle(.primary)

        VStack(alignment: .leading, spacing: 3) {
          Text("添加子任务")
            .font(.body)
            .foregroundStyle(.primary)

          Text("不用进编辑器也能先补一条")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 8)
      }

      HStack(spacing: 10) {
        TextField("补一个下一步…", text: $title)
          .textFieldStyle(.plain)
          .submitLabel(.done)
          .onSubmit(onSubmit)

        Button(action: onSubmit) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title3)
            .foregroundStyle(submitEnabled ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!submitEnabled)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(NornTheme.cardSurfaceMuted)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(NornTheme.border, lineWidth: 1)
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
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
