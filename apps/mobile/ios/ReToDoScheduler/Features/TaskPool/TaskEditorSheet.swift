import SwiftUI

struct TaskEditorSheet: View {
  @FocusState private var isInputFocused: Bool

  let editingTaskID: String?
  let allTasks: [Task]
  let initialDraft: TaskEditorDraft
  let onCancel: () -> Void
  let onSave: (TaskEditorDraft) -> Void

  @State private var draft: TaskEditorDraft

  init(
    editingTaskID: String?,
    allTasks: [Task],
    initialDraft: TaskEditorDraft,
    onCancel: @escaping () -> Void,
    onSave: @escaping (TaskEditorDraft) -> Void
  ) {
    self.editingTaskID = editingTaskID
    self.allTasks = allTasks
    self.initialDraft = initialDraft
    self.onCancel = onCancel
    self.onSave = onSave
    _draft = State(initialValue: initialDraft)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("基本信息") {
          TextField("标题", text: $draft.title)
            .focused($isInputFocused)
          TextField("描述", text: $draft.description, axis: .vertical)
            .focused($isInputFocused)
          TextField("标签（逗号分隔）", text: $draft.tagsText)
            .focused($isInputFocused)
        }

        Section("约束与价值") {
          TextField("总耗时（分钟）", text: $draft.estimatedMinutes)
            .keyboardType(.numberPad)
            .focused($isInputFocused)
          TextField("最小块（分钟）", text: $draft.minChunkMinutes)
            .keyboardType(.numberPad)
            .focused($isInputFocused)
          Toggle("设置截止日期", isOn: $draft.hasDueDate)
          if draft.hasDueDate {
            DatePicker("截止日期", selection: $draft.dueDate, displayedComponents: .date)
          }
          TextField("按时收益", text: $draft.rewardOnTime)
            .keyboardType(.numberPad)
            .focused($isInputFocused)
          TextField("错过损失", text: $draft.penaltyMissed)
            .keyboardType(.numberPad)
            .focused($isInputFocused)
        }

        Section("任务依赖") {
          let candidates = allTasks.filter { $0.id != (editingTaskID ?? "") && $0.status != .archived }
          if candidates.isEmpty {
            Text("当前没有可依赖的其他任务。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          } else {
            ForEach(candidates) { candidate in
              Toggle(
                candidate.title,
                isOn: Binding(
                  get: { draft.dependsOnTaskIds.contains(candidate.id) },
                  set: { enabled in
                    if enabled {
                      if !draft.dependsOnTaskIds.contains(candidate.id) {
                        draft.dependsOnTaskIds.append(candidate.id)
                      }
                    } else {
                      draft.dependsOnTaskIds.removeAll { $0 == candidate.id }
                    }
                  }
                )
              )
            }
          }
        }

        Section {
          Button("添加步骤") {
            draft.addStep()
          }
        } header: {
          Text("子步骤")
        } footer: {
          if draft.steps.isEmpty {
            Text("留空表示该任务直接作为一个调度单元。")
          }
        }

        ForEach(draft.steps) { step in
          Section(step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "步骤" : step.title) {
            TextField(
              "步骤 ID",
              text: binding(for: step.id, keyPath: \.stepID)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isInputFocused)

            TextField(
              "步骤标题",
              text: binding(for: step.id, keyPath: \.title)
            )
            .focused($isInputFocused)

            TextField(
              "耗时（分钟）",
              text: binding(for: step.id, keyPath: \.estimatedMinutes)
            )
            .keyboardType(.numberPad)
            .focused($isInputFocused)

            TextField(
              "最小块（分钟）",
              text: binding(for: step.id, keyPath: \.minChunkMinutes)
            )
            .keyboardType(.numberPad)
            .focused($isInputFocused)

            TextField(
              "依赖步骤 ID（逗号分隔）",
              text: binding(for: step.id, keyPath: \.dependsOnStepIDsText)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isInputFocused)

            Button("删除步骤", role: .destructive) {
              draft.removeStep(id: step.id)
            }
          }
        }

        Section("任务特征") {
          Picker("专注度", selection: $draft.focus) {
            Text("高").tag(FocusLevel.high)
            Text("中").tag(FocusLevel.medium)
            Text("低").tag(FocusLevel.low)
          }

          Picker("可中断性", selection: $draft.interruptibility) {
            Text("低").tag(Interruptibility.low)
            Text("中").tag(Interruptibility.medium)
            Text("高").tag(Interruptibility.high)
          }

          Picker("场所", selection: $draft.location) {
            Text("不限").tag(LocationType.any)
            Text("室内").tag(LocationType.indoor)
            Text("室外").tag(LocationType.outdoor)
          }

          Picker("设备", selection: $draft.device) {
            Text("不限").tag(DeviceType.any)
            Text("桌面").tag(DeviceType.desktop)
            Text("移动").tag(DeviceType.mobile)
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .simultaneousGesture(
        TapGesture().onEnded {
          isInputFocused = false
        }
      )
      .navigationTitle(editingTaskID == nil ? "新建任务" : "编辑任务")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            isInputFocused = false
            onCancel()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            isInputFocused = false
            onSave(draft)
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()

          Button("完成") {
            isInputFocused = false
          }
        }
      }
    }
  }

  private func binding(
    for stepID: UUID,
    keyPath: WritableKeyPath<TaskEditorStepDraft, String>
  ) -> Binding<String> {
    Binding(
      get: {
        draft.steps.first(where: { $0.id == stepID })?[keyPath: keyPath] ?? ""
      },
      set: { newValue in
        guard let index = draft.steps.firstIndex(where: { $0.id == stepID }) else { return }
        draft.steps[index][keyPath: keyPath] = newValue
      }
    )
  }
}
