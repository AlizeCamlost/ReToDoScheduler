import SwiftUI

struct TaskPoolSection: View {
  @Binding var searchQuery: String
  let tasks: [Task]
  let onCreateDetailedTask: () -> Void
  let onToggleDone: (Task) -> Void
  let onArchive: (Task) -> Void
  let onEdit: (Task) -> Void

  var body: some View {
    Section("任务池") {
      TextField("搜索任务", text: $searchQuery)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

      Button("新建详情任务", action: onCreateDetailedTask)

      if tasks.isEmpty {
        Text("没有匹配的任务。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(tasks) { task in
          VStack(alignment: .leading, spacing: 8) {
            Button {
              onEdit(task)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                  .font(.headline)
                  .strikethrough(task.status == .done)
                  .foregroundStyle(task.status == .done ? .secondary : .primary)
                Text(AppFormatters.taskMeta(task))
                  .font(.footnote)
                  .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                  if let dueLabel = AppFormatters.dueLabel(for: task.dueAt) {
                    Text(dueLabel)
                  }
                  if !task.dependsOnTaskIds.isEmpty {
                    Text("依赖 \(task.dependsOnTaskIds.count)")
                  }
                  if !task.steps.isEmpty {
                    Text("步骤 \(task.steps.count)")
                  }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack {
              Button(task.status == .done ? "标为待办" : "完成") {
                onToggleDone(task)
              }
              .buttonStyle(.bordered)

              Button("编辑") {
                onEdit(task)
              }
              .buttonStyle(.bordered)

              Button("归档", role: .destructive) {
                onArchive(task)
              }
              .buttonStyle(.bordered)
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
  }
}
