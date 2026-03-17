import SwiftUI

struct TaskPoolSection: View {
  @Binding var searchQuery: String
  var keyboardFocus: FocusState<Bool>.Binding
  let tasks: [Task]
  let onCreateDetailedTask: () -> Void
  let onToggleDone: (Task) -> Void
  let onArchive: (Task) -> Void
  let onOpenDetail: (Task) -> Void
  let onEdit: (Task) -> Void

  private var highlightedTask: Task? {
    tasks.first
  }

  private var secondaryTasks: [Task] {
    Array(tasks.dropFirst())
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 10) {
          Text("任务流")
            .font(.system(size: 32, weight: .bold, design: .rounded))
          Text("以线性视角整理待办，并始终保留一个能快速落笔的输入口。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
              .foregroundStyle(.secondary)
            TextField("搜索任务、标签或描述", text: $searchQuery)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .focused(keyboardFocus)
              .submitLabel(.done)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
              .fill(Color.white.opacity(0.54))
          )

          Button(action: onCreateDetailedTask) {
            Label("新建详情任务", systemImage: "square.and.pencil")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.black.opacity(0.82))
        }

        if let highlightedTask {
          VStack(alignment: .leading, spacing: 12) {
            Text("当前聚焦")
              .font(.headline.weight(.semibold))
            TaskPoolCard(
              task: highlightedTask,
              emphasized: true,
              onToggleDone: { onToggleDone(highlightedTask) },
              onArchive: { onArchive(highlightedTask) },
              onOpenDetail: { onOpenDetail(highlightedTask) },
              onEdit: { onEdit(highlightedTask) }
            )
          }
        }

        VStack(alignment: .leading, spacing: 14) {
          Text("任务队列")
            .font(.headline.weight(.semibold))

          if tasks.isEmpty {
            EmptyTaskPoolCard()
          } else {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
              TaskPoolCard(
                task: task,
                emphasized: index == 0,
                onToggleDone: { onToggleDone(task) },
                onArchive: { onArchive(task) },
                onOpenDetail: { onOpenDetail(task) },
                onEdit: { onEdit(task) }
              )
            }
          }

          if !secondaryTasks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text("后续队列")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
              ForEach(secondaryTasks.prefix(3)) { task in
                HStack(spacing: 10) {
                  Circle()
                    .fill(task.status.accentColor.opacity(0.8))
                    .frame(width: 8, height: 8)
                  Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                  Spacer()
                  if let dueLabel = AppFormatters.dueLabel(for: task.dueAt) {
                    Text(dueLabel)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
            .padding(16)
            .background(
              RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 8]))
                .foregroundStyle(Color.primary.opacity(0.14))
            )
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 168)
    }
  }
}

private struct TaskPoolCard: View {
  let task: Task
  let emphasized: Bool
  let onToggleDone: () -> Void
  let onArchive: () -> Void
  let onOpenDetail: () -> Void
  let onEdit: () -> Void

  private var metaItems: [String] {
    var items = ["估时 \(task.estimatedMinutes) 分钟"]
    if let dueLabel = AppFormatters.dueLabel(for: task.dueAt) {
      items.append(dueLabel)
    }
    if !task.tags.isEmpty {
      items.append(task.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
    }
    return items
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(spacing: 0) {
        Circle()
          .fill(task.status.accentColor)
          .frame(width: emphasized ? 15 : 13, height: emphasized ? 15 : 13)
          .overlay(
            Circle()
              .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
          )
          .padding(.top, 10)

        RoundedRectangle(cornerRadius: 999, style: .continuous)
          .fill(
            LinearGradient(
              colors: [task.status.accentColor.opacity(0.55), task.status.accentColor.opacity(0.04)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 2)
          .frame(maxHeight: .infinity)
          .padding(.top, 8)
          .padding(.bottom, 6)
      }

      VStack(alignment: .leading, spacing: 12) {
        Button(action: onOpenDetail) {
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
              VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                  .font(.headline.weight(.semibold))
                  .foregroundStyle(.primary)
                  .lineLimit(2)
                Text(task.status.displayName)
                  .font(.caption.weight(.medium))
                  .foregroundStyle(task.status.accentColor)
              }

              Spacer()

              Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }

            if let description = task.description, !description.isEmpty {
              Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            HStack(spacing: 8) {
              ForEach(metaItems, id: \.self) { item in
                Text(item)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(Color.white.opacity(0.52), in: Capsule())
              }
            }

            if !task.steps.isEmpty {
              Text("包含 \(task.steps.count) 个子任务")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)

        HStack(spacing: 10) {
          Button(task.status == .done ? "标为待办" : "完成", action: onToggleDone)
            .buttonStyle(.borderedProminent)
            .tint(task.status == .done ? Color.gray.opacity(0.6) : task.status.accentColor)

          Button("编辑", action: onEdit)
            .buttonStyle(.bordered)

          Menu {
            Button("查看详情", action: onOpenDetail)
            Button("归档", role: .destructive, action: onArchive)
          } label: {
            Image(systemName: "ellipsis")
              .font(.body.weight(.bold))
              .frame(width: 34, height: 34)
              .background(Color.white.opacity(0.45), in: Circle())
          }
        }
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: emphasized ? 30 : 26, style: .continuous)
          .fill(
            LinearGradient(
              colors: emphasized
                ? [Color.white.opacity(0.82), Color.white.opacity(0.54)]
                : [Color.white.opacity(0.66), Color.white.opacity(0.4)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: emphasized ? 30 : 26, style: .continuous)
          .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(emphasized ? 0.12 : 0.08), radius: emphasized ? 18 : 10, y: emphasized ? 8 : 4)
    }
  }
}

private struct EmptyTaskPoolCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("任务池是空的")
        .font(.headline.weight(.semibold))
      Text("先在底部输入栏写下一件要做的事，时间视图会随之生成。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(Color.white.opacity(0.5))
    )
  }
}

extension TaskStatus {
  var accentColor: Color {
    switch self {
    case .todo:
      return Color(red: 0.19, green: 0.38, blue: 0.83)
    case .doing:
      return Color(red: 0.94, green: 0.57, blue: 0.15)
    case .done:
      return Color(red: 0.18, green: 0.61, blue: 0.39)
    case .archived:
      return Color.gray
    }
  }

  var displayName: String {
    switch self {
    case .todo: return "待开始"
    case .doing: return "进行中"
    case .done: return "已完成"
    case .archived: return "已归档"
    }
  }
}
