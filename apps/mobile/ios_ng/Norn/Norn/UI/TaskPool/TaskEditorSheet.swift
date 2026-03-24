import SwiftUI

struct TaskEditorSheet: View {
  let allTasks: [Task]
  let onSave: (TaskDraft) -> Void
  let onCancel: () -> Void

  @State private var draft: TaskDraft
  @State private var tagsInput: String
  @State private var editableSteps: [EditableStep]
  @State private var isDependencyPickerPresented = false

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

  private var selectedDependencyTasks: [Task] {
    let tasksByID = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })
    return draft.dependsOnTaskIDs.compactMap { tasksByID[$0] }
  }

  private var dependencySummaryText: String {
    let count = draft.dependsOnTaskIDs.count
    guard count > 0 else {
      return "尚未选择前置依赖"
    }

    let names = selectedDependencyTasks.prefix(2).map(\.title)
    guard !names.isEmpty else {
      return "已选 \(count) 项"
    }

    let suffix = count > names.count ? " 等 \(count) 项" : ""
    return names.joined(separator: " · ") + suffix
  }

  var body: some View {
    NavigationStack {
      ZStack {
        NornScreenBackground()

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
      .sheet(isPresented: $isDependencyPickerPresented) {
        TaskDependencyPickerSheet(
          currentTaskID: draft.id,
          allTasks: allTasks,
          selectedTaskIDs: $draft.dependsOnTaskIDs
        )
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
    Section("前置依赖") {
      Button {
        isDependencyPickerPresented = true
      } label: {
        DependencySummaryRow(
          title: "前置依赖",
          subtitle: dependencySummaryText,
          count: draft.dependsOnTaskIDs.count
        )
      }
      .buttonStyle(.plain)

      if !selectedDependencyTasks.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(selectedDependencyTasks.prefix(4)) { task in
              DependencyChip(title: task.title)
            }
            if selectedDependencyTasks.count > 4 {
              DependencyChip(title: "另有 \(selectedDependencyTasks.count - 4) 项")
            }
          }
          .padding(.vertical, 2)
        }
      } else {
        Text("从这里为当前任务挑选前置依赖，支持搜索和筛选。")
          .font(.footnote)
          .foregroundStyle(.secondary)
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

private struct DependencySummaryRow: View {
  let title: String
  let subtitle: String
  let count: Int

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
      }

      Spacer(minLength: 8)

      HStack(spacing: 8) {
        if count > 0 {
          Text("\(count)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(NornTheme.pillSurface, in: Capsule())
        }

        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }
}

private struct DependencyChip: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption.weight(.medium))
      .foregroundStyle(.primary)
      .lineLimit(1)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(NornTheme.pillSurface, in: Capsule())
      .overlay(
        Capsule()
          .strokeBorder(NornTheme.border, lineWidth: 1)
      )
  }
}

private struct EditableStep {
  var id: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dependsOnStepIDsText: String
  var rawPayload: [String: JSONValue]

  init(step: TaskStep) {
    id = step.id
    title = step.title
    estimatedMinutes = step.estimatedMinutes
    minChunkMinutes = step.minChunkMinutes
    dependsOnStepIDsText = step.dependsOnStepIDs.joined(separator: ", ")
    rawPayload = Self.encodedPayload(from: step)
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
    self.rawPayload = [:]
  }

  var taskStep: TaskStep {
    let payload = mergedPayload()
    if let decoded = Self.decodedTaskStep(from: payload) {
      return decoded
    }

    return TaskStep(
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

  private func mergedPayload() -> [String: JSONValue] {
    var payload = rawPayload
    payload["id"] = .string(id)
    payload["title"] = .string(title)
    payload["estimatedMinutes"] = .number(Double(estimatedMinutes))
    payload["minChunkMinutes"] = .number(Double(minChunkMinutes))
    payload["dependsOnStepIDs"] = .array(
      dependsOnStepIDsText
        .split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map(JSONValue.string)
    )
    return payload
  }

  private static func encodedPayload(from step: TaskStep) -> [String: JSONValue] {
    guard
      let data = try? JSONEncoder().encode(step),
      let payload = try? JSONDecoder().decode([String: JSONValue].self, from: data)
    else {
      return [:]
    }

    return payload
  }

  private static func decodedTaskStep(from payload: [String: JSONValue]) -> TaskStep? {
    guard let data = try? JSONEncoder().encode(payload) else {
      return nil
    }

    return try? JSONDecoder().decode(TaskStep.self, from: data)
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
