import SwiftUI

struct TaskSequenceEditorSheet: View {
  let onSave: (TaskSequenceDraft) -> Void
  let onCancel: () -> Void

  @State private var draft: TaskSequenceDraft
  @FocusState private var focusedEntryID: UUID?

  init(
    draft: TaskSequenceDraft,
    onSave: @escaping (TaskSequenceDraft) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onSave = onSave
    self.onCancel = onCancel
    _draft = State(initialValue: draft)
  }

  private var canSave: Bool {
    draft.entries.contains { !$0.rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        NornScreenBackground()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 18) {
            introCard
            sequenceTitleCard

            VStack(alignment: .leading, spacing: 12) {
              Text("任务描述")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

              ForEach(Array(draft.entries.enumerated()), id: \.element.id) { index, entry in
                entryCard(for: entry, index: index)
              }

              Button(action: appendEntry) {
                Label("继续添加一项", systemImage: "plus")
                  .font(.subheadline.weight(.semibold))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 12)
                  .background(NornTheme.cardSurfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 18)
          .padding(.bottom, 32)
        }
      }
      .navigationTitle("任务序列")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("取消", action: onCancel)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button("保存") {
            onSave(normalizedDraft)
          }
          .disabled(!canSave)
        }
      }
      .onAppear {
        focusedEntryID = draft.entries.first?.id
      }
    }
  }

  private var introCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("把今天这半天要串着处理的事项先一起录下来。")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)

      Text("每一行都支持和 Quick Add 一样的语法，比如 `45m`、`#work`、`明天`。保存后这些任务会共享一个序列标识，但仍然按单卡展示。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }

  private var sequenceTitleCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("序列标签")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)

      TextField("可选，例如 今天上午 / 今天下午", text: $draft.title)
        .textFieldStyle(.plain)
        .font(.body)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(NornTheme.border, lineWidth: 1)
    )
  }

  private func entryCard(for entry: TaskSequenceEntryDraft, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center) {
        Text("第 \(index + 1) 项")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.secondary)

        Spacer()

        if draft.entries.count > 1 {
          Button(role: .destructive) {
            removeEntry(entry.id)
          } label: {
            Image(systemName: "trash")
              .font(.footnote.weight(.semibold))
          }
          .buttonStyle(.plain)
        }
      }

      TextField(
        "例如：整理晨会纪要 #team 20m",
        text: entryBinding(for: entry.id),
        axis: .vertical
      )
      .focused($focusedEntryID, equals: entry.id)
      .lineLimit(2...4)
      .textFieldStyle(.plain)
      .font(.body)

      if let preview = previewDraft(for: entry.rawInput) {
        HStack(spacing: 8) {
          Text(preview.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Text("\(preview.estimatedMinutes) 分钟")
            .font(.caption)
            .foregroundStyle(.secondary)

          if !preview.tags.isEmpty {
            Text(preview.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
              .font(.caption)
              .foregroundStyle(.tertiary)
              .lineLimit(1)
          }

          if let dueLabel = RelativeDueDateFormatter.label(for: preview.dueAt) {
            Text(dueLabel)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } else {
        Text("留空的行不会保存。")
          .font(.caption)
          .foregroundStyle(.tertiary)
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

  private var normalizedDraft: TaskSequenceDraft {
    TaskSequenceDraft(
      title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
      entries: draft.entries
    )
  }

  private func entryBinding(for id: UUID) -> Binding<String> {
    Binding(
      get: {
        draft.entries.first(where: { $0.id == id })?.rawInput ?? ""
      },
      set: { newValue in
        guard let index = draft.entries.firstIndex(where: { $0.id == id }) else { return }
        draft.entries[index].rawInput = newValue
      }
    )
  }

  private func previewDraft(for rawInput: String) -> QuickAddDraft? {
    QuickAddDraft.parse(rawInput: rawInput)
  }

  private func appendEntry() {
    let entry = TaskSequenceEntryDraft()
    draft.entries.append(entry)
    focusedEntryID = entry.id
  }

  private func removeEntry(_ id: UUID) {
    guard let index = draft.entries.firstIndex(where: { $0.id == id }) else { return }
    draft.entries.remove(at: index)
    if draft.entries.isEmpty {
      let replacement = TaskSequenceEntryDraft()
      draft.entries = [replacement]
      focusedEntryID = replacement.id
      return
    }

    focusedEntryID = draft.entries[min(index, draft.entries.count - 1)].id
  }
}

#Preview {
  TaskSequenceEditorSheet(
    draft: TaskSequenceDraft(
      title: "今天上午",
      entries: [
        TaskSequenceEntryDraft(rawInput: "写日报 #work 20m"),
        TaskSequenceEntryDraft(rawInput: "回邮件 15m")
      ]
    ),
    onSave: { _ in },
    onCancel: {}
  )
}
