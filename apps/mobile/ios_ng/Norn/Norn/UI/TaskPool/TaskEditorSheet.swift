import SwiftUI

struct TaskEditorSheet: View {
  let allTasks: [Task]
  let onSave: (TaskDraft) -> Void
  let onCancel: () -> Void

  @State private var draft: TaskDraft
  @State private var tagsInput: String
  @State private var editableSteps: [EditableStep]

  init(
    draft: TaskDraft,
    allTasks: [Task],
    onSave: @escaping (TaskDraft) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.allTasks = allTasks
    self.onSave = onSave
    self.onCancel = onCancel
    _draft = State(initialValue: draft)
    _tagsInput = State(initialValue: draft.tags.joined(separator: ", "))
    _editableSteps = State(initialValue: draft.steps.map(EditableStep.init(step:)))
  }

  private var dependencyCandidates: [Task] {
    allTasks.filter { candidate in
      let isSameTask = draft.id == candidate.id
      return !isSameTask && candidate.status != .archived
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [
            Color(red: 0.98, green: 0.97, blue: 0.92),
            Color(red: 0.94, green: 0.96, blue: 0.99)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        Form {
          basicSection
          constraintSection
          dependencySection
          stepSection
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle(draft.id == nil ? "新建任务" : "编辑任务")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("取消", action: onCancel)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button("保存") {
            onSave(normalizedDraft)
          }
          .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private var basicSection: some View {
    Section("基本信息") {
      TextField("标题", text: $draft.title)
      TextField("描述", text: $draft.description, axis: .vertical)
        .lineLimit(3...6)
      TextField("标签（逗号分隔）", text: $tagsInput)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      Picker("状态", selection: $draft.status) {
        ForEach(TaskStatus.allCases, id: \.self) { status in
          Text(TaskDisplayFormatter.statusLabel(for: status)).tag(status)
        }
      }
    }
  }

  private var constraintSection: some View {
    Section("约束与价值") {
      Stepper(value: $draft.estimatedMinutes, in: 1...1440, step: 5) {
        editorMetricRow(title: "总耗时", value: "\(draft.estimatedMinutes) 分钟")
      }
      Stepper(value: $draft.minChunkMinutes, in: 1...480, step: 5) {
        editorMetricRow(title: "最小块", value: "\(draft.minChunkMinutes) 分钟")
      }
      Toggle("设置截止日期", isOn: hasDueDateBinding)
      if draft.dueAt != nil {
        DatePicker("截止日期", selection: dueDateBinding, displayedComponents: .date)
      }
      Stepper(value: $draft.scheduleValue.rewardOnTime, in: 0...999, step: 1) {
        editorMetricRow(title: "按时收益", value: "\(draft.scheduleValue.rewardOnTime)")
      }
      Stepper(value: $draft.scheduleValue.penaltyMissed, in: 0...999, step: 1) {
        editorMetricRow(title: "错过损失", value: "\(draft.scheduleValue.penaltyMissed)")
      }
    }
  }

  private var dependencySection: some View {
    Section("任务依赖") {
      if dependencyCandidates.isEmpty {
        Text("当前没有可依赖的其他任务。")
          .foregroundStyle(.secondary)
      } else {
        ForEach(dependencyCandidates) { candidate in
          Toggle(isOn: dependencyBinding(for: candidate.id)) {
            VStack(alignment: .leading, spacing: 4) {
              Text(candidate.title)
              Text(candidate.id)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private var stepSection: some View {
    Section {
      if editableSteps.isEmpty {
        Text("留空表示该任务直接作为一个调度单元。")
          .foregroundStyle(.secondary)
      }

      ForEach(Array(editableSteps.indices), id: \.self) { index in
        VStack(alignment: .leading, spacing: 12) {
          TextField("步骤标题", text: stepTitleBinding(for: index))
          TextField("步骤 ID（可选）", text: stepIDBinding(for: index))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          Stepper(value: stepEstimatedMinutesBinding(for: index), in: 1...720, step: 5) {
            editorMetricRow(title: "步骤耗时", value: "\(editableSteps[index].estimatedMinutes) 分钟")
          }
          Stepper(value: stepMinChunkMinutesBinding(for: index), in: 1...720, step: 5) {
            editorMetricRow(title: "步骤最小块", value: "\(editableSteps[index].minChunkMinutes) 分钟")
          }
          TextField("依赖步骤 ID（逗号分隔）", text: stepDependsOnTextBinding(for: index))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          Button("删除步骤", role: .destructive) {
            editableSteps.remove(at: index)
          }
        }
        .padding(.vertical, 6)
      }

      Button("添加步骤") {
        addStep()
      }
    } header: {
      Text("子步骤")
    } footer: {
      Text("步骤依赖使用步骤 ID，多个值用逗号分隔。")
    }
  }

  private var normalizedDraft: TaskDraft {
    var nextDraft = draft
    nextDraft.tags = tagsInput
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    nextDraft.steps = editableSteps.map(\.taskStep)
    if nextDraft.rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      nextDraft.rawInput = nextDraft.title
    }
    return nextDraft
  }

  private var hasDueDateBinding: Binding<Bool> {
    Binding(
      get: { draft.dueAt != nil },
      set: { enabled in
        if enabled {
          draft.dueAt = draft.dueAt ?? Calendar.current.startOfDay(for: Date())
        } else {
          draft.dueAt = nil
        }
      }
    )
  }

  private var dueDateBinding: Binding<Date> {
    Binding(
      get: { draft.dueAt ?? Calendar.current.startOfDay(for: Date()) },
      set: { draft.dueAt = $0 }
    )
  }

  private func dependencyBinding(for taskID: String) -> Binding<Bool> {
    Binding(
      get: { draft.dependsOnTaskIDs.contains(taskID) },
      set: { selected in
        if selected {
          if !draft.dependsOnTaskIDs.contains(taskID) {
            draft.dependsOnTaskIDs.append(taskID)
          }
        } else {
          draft.dependsOnTaskIDs.removeAll { $0 == taskID }
        }
      }
    )
  }

  private func stepTitleBinding(for index: Int) -> Binding<String> {
    Binding(
      get: { editableSteps[index].title },
      set: { editableSteps[index].title = $0 }
    )
  }

  private func stepIDBinding(for index: Int) -> Binding<String> {
    Binding(
      get: { editableSteps[index].id },
      set: { editableSteps[index].id = $0 }
    )
  }

  private func stepEstimatedMinutesBinding(for index: Int) -> Binding<Int> {
    Binding(
      get: { editableSteps[index].estimatedMinutes },
      set: { editableSteps[index].estimatedMinutes = $0 }
    )
  }

  private func stepMinChunkMinutesBinding(for index: Int) -> Binding<Int> {
    Binding(
      get: { editableSteps[index].minChunkMinutes },
      set: { editableSteps[index].minChunkMinutes = $0 }
    )
  }

  private func stepDependsOnTextBinding(for index: Int) -> Binding<String> {
    Binding(
      get: { editableSteps[index].dependsOnStepIDsText },
      set: { editableSteps[index].dependsOnStepIDsText = $0 }
    )
  }

  private func addStep() {
    editableSteps.append(
      EditableStep(
        id: "step-\(editableSteps.count + 1)",
        title: "",
        estimatedMinutes: 30,
        minChunkMinutes: 25,
        dependsOnStepIDsText: editableSteps.last?.id ?? ""
      )
    )
  }

  private func editorMetricRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text(value)
        .foregroundStyle(.secondary)
    }
  }
}

private struct EditableStep {
  var id: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dependsOnStepIDsText: String

  init(step: TaskStep) {
    id = step.id
    title = step.title
    estimatedMinutes = step.estimatedMinutes
    minChunkMinutes = step.minChunkMinutes
    dependsOnStepIDsText = step.dependsOnStepIDs.joined(separator: ", ")
  }

  init(
    id: String,
    title: String,
    estimatedMinutes: Int,
    minChunkMinutes: Int,
    dependsOnStepIDsText: String
  ) {
    self.id = id
    self.title = title
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dependsOnStepIDsText = dependsOnStepIDsText
  }

  var taskStep: TaskStep {
    TaskStep(
      id: id,
      title: title,
      estimatedMinutes: estimatedMinutes,
      minChunkMinutes: minChunkMinutes,
      dependsOnStepIDs: dependsOnStepIDsText
        .split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    )
  }
}

#Preview {
  TaskEditorSheet(
    draft: TaskDraft(task: NornPreviewFixtures.tasks[0]),
    allTasks: NornPreviewFixtures.tasks,
    onSave: { _ in },
    onCancel: {}
  )
}
