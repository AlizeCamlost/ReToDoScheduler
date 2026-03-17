import SwiftUI

struct AppView: View {
  @StateObject private var viewModel = AppViewModel()
  @FocusState private var isInputFocused: Bool

  var body: some View {
    NavigationStack {
      ZStack {
        AppBackdrop(perspective: viewModel.currentPerspective)

        TabView(selection: $viewModel.currentPerspective) {
          TaskPoolSection(
            searchQuery: $viewModel.searchQuery,
            keyboardFocus: $isInputFocused,
            tasks: viewModel.filteredTasks,
            onCreateDetailedTask: {
              isInputFocused = false
              viewModel.openCreateTaskEditor()
            },
            onToggleDone: { task in
              isInputFocused = false
              _Concurrency.Task { await viewModel.toggleDone(task) }
            },
            onArchive: { task in
              isInputFocused = false
              _Concurrency.Task { await viewModel.archive(task) }
            },
            onOpenDetail: { task in
              isInputFocused = false
              withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                viewModel.openTaskDetail(task)
              }
            },
            onEdit: { task in
              isInputFocused = false
              viewModel.openEditor(for: task)
            }
          )
          .tag(HomePerspective.tasks)

          ScheduleSection(
            calendarMode: $viewModel.calendarMode,
            scheduleView: viewModel.scheduleView,
            titleForBlock: viewModel.taskTitle(for:),
            taskForBlock: viewModel.task(for:),
            taskForID: viewModel.task(for:),
            onSelectTask: { task in
              isInputFocused = false
              withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                viewModel.openTaskDetail(task)
              }
            }
          )
          .tag(HomePerspective.calendar)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .padding(.top, 112)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: viewModel.currentPerspective) { _ in
          isInputFocused = false
        }

        VStack(spacing: 0) {
          AppChromeHeader(
            currentPerspective: $viewModel.currentPerspective,
            syncMessage: viewModel.syncMessage,
            isSyncing: viewModel.isSyncing,
            onSync: {
              isInputFocused = false
              _Concurrency.Task { await viewModel.syncNow() }
            },
            onSettings: {
              isInputFocused = false
              viewModel.showingSettings = true
            }
          )
          .padding(.horizontal, 20)
          .padding(.top, 8)

          Spacer()
        }
        .ignoresSafeArea(edges: .top)

        VStack {
          Spacer()

          if viewModel.currentPerspective == .tasks {
            QuickAddSection(
              input: $viewModel.input,
              keyboardFocus: $isInputFocused,
              syncMessage: viewModel.syncMessage,
              isSyncing: viewModel.isSyncing,
              onAdd: { _Concurrency.Task { await viewModel.addTask() } },
              onSync: {
                isInputFocused = false
                _Concurrency.Task { await viewModel.syncNow() }
              }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .ignoresSafeArea(edges: .bottom)

        if let task = viewModel.selectedTask {
          TaskDetailOverlay(
            task: task,
            onClose: {
              withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                viewModel.closeTaskDetail()
              }
            },
            onToggleDone: {
              _Concurrency.Task { await viewModel.toggleDone(task) }
            },
            onEdit: {
              viewModel.openEditor(for: task)
            },
            onArchive: {
              _Concurrency.Task { await viewModel.archive(task) }
            }
          )
          .transition(.opacity.combined(with: .move(edge: .bottom)))
          .zIndex(10)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .sheet(isPresented: $viewModel.showingSettings) {
        SettingsSheet(
          apiBaseURL: $viewModel.apiBaseURL,
          apiAuthToken: $viewModel.apiAuthToken,
          timeTemplate: $viewModel.timeTemplate,
          onClose: { viewModel.showingSettings = false },
          onSave: viewModel.saveSettings
        )
      }
      .sheet(isPresented: $viewModel.showingTaskEditor) {
        TaskEditorSheet(
          editingTaskID: viewModel.editingTaskID,
          allTasks: viewModel.visibleTasks,
          initialDraft: viewModel.taskEditorDraft,
          onCancel: viewModel.closeTaskEditor,
          onSave: { draft in
            _Concurrency.Task { await viewModel.saveTaskEditor(draft) }
          }
        )
      }
      .task {
        await viewModel.bootstrap()
      }
    }
  }
}

private struct AppChromeHeader: View {
  @Binding var currentPerspective: HomePerspective
  let syncMessage: String
  let isSyncing: Bool
  let onSync: () -> Void
  let onSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("ReToDo")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
          Text(currentPerspective.title)
            .font(.system(size: 28, weight: .bold, design: .rounded))
        }

        Spacer()

        HeaderIconButton(
          systemName: isSyncing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath",
          action: onSync
        )

        HeaderIconButton(systemName: "gearshape", action: onSettings)
      }

      HStack(spacing: 10) {
        ForEach(HomePerspective.allCases) { perspective in
          Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
              currentPerspective = perspective
            }
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(perspective.title)
                .font(.subheadline.weight(.semibold))
              Text(perspective.subtitle)
                .font(.caption2)
                .lineLimit(1)
            }
            .foregroundStyle(currentPerspective == perspective ? Color.black : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(currentPerspective == perspective ? Color.white.opacity(0.85) : Color.white.opacity(0.28))
            )
          }
          .buttonStyle(.plain)
        }
      }

      Text(syncMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(16)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
  }
}

private struct HeaderIconButton: View {
  let systemName: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.headline)
        .frame(width: 40, height: 40)
        .background(Color.white.opacity(0.7), in: Circle())
    }
    .buttonStyle(.plain)
  }
}

private struct AppBackdrop: View {
  let perspective: HomePerspective

  var body: some View {
    ZStack {
      LinearGradient(
        colors: gradientColors,
        startPoint: perspective == .tasks ? .topLeading : .topTrailing,
        endPoint: perspective == .tasks ? .bottomTrailing : .bottomLeading
      )
      .ignoresSafeArea()

      Circle()
        .fill(accentColor.opacity(0.18))
        .frame(width: 300, height: 300)
        .blur(radius: 16)
        .offset(x: perspective == .tasks ? -120 : 110, y: -250)

      RoundedRectangle(cornerRadius: 80, style: .continuous)
        .fill(Color.white.opacity(0.08))
        .frame(width: perspective == .tasks ? 220 : 260, height: perspective == .tasks ? 420 : 360)
        .rotationEffect(.degrees(perspective == .tasks ? -18 : 12))
        .offset(x: perspective == .tasks ? 170 : -140, y: 120)
        .blur(radius: 2)

      if perspective == .calendar {
        GridGlow()
          .opacity(0.55)
      }
    }
    .animation(.easeInOut(duration: 0.45), value: perspective)
  }

  private var gradientColors: [Color] {
    switch perspective {
    case .tasks:
      return [
        Color(red: 0.97, green: 0.93, blue: 0.88),
        Color(red: 0.90, green: 0.94, blue: 0.98),
        Color(red: 0.96, green: 0.96, blue: 0.98)
      ]
    case .calendar:
      return [
        Color(red: 0.90, green: 0.95, blue: 0.99),
        Color(red: 0.84, green: 0.90, blue: 0.98),
        Color(red: 0.94, green: 0.94, blue: 0.98)
      ]
    }
  }

  private var accentColor: Color {
    perspective == .tasks ? Color.orange : Color.blue
  }
}

private struct GridGlow: View {
  var body: some View {
    GeometryReader { geometry in
      Path { path in
        let spacing: CGFloat = 48
        let columns = Int(geometry.size.width / spacing) + 2
        let rows = Int(geometry.size.height / spacing) + 2

        for index in 0..<columns {
          let x = CGFloat(index) * spacing
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x, y: geometry.size.height))
        }

        for index in 0..<rows {
          let y = CGFloat(index) * spacing
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: geometry.size.width, y: y))
        }
      }
      .stroke(Color.white.opacity(0.14), lineWidth: 1)
      .blur(radius: 0.4)
    }
    .ignoresSafeArea()
  }
}

private struct TaskDetailOverlay: View {
  let task: Task
  let onClose: () -> Void
  let onToggleDone: () -> Void
  let onEdit: () -> Void
  let onArchive: () -> Void

  @State private var isSubtasksExpanded = false

  private var orderedSteps: [TaskStepTemplate] {
    Array(task.steps.reversed())
  }

  private var visibleSteps: [TaskStepTemplate] {
    isSubtasksExpanded ? orderedSteps : Array(orderedSteps.prefix(1))
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.28)
        .ignoresSafeArea()
        .onTapGesture(perform: onClose)

      VStack(spacing: 0) {
        Capsule()
          .fill(Color.primary.opacity(0.15))
          .frame(width: 44, height: 5)
          .padding(.top, 10)

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                  .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(task.status.displayName)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(task.status.accentColor)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(task.status.accentColor.opacity(0.12), in: Capsule())
              }

              Spacer()

              Button(action: onClose) {
                Image(systemName: "xmark")
                  .font(.headline)
                  .frame(width: 36, height: 36)
                  .background(Color.black.opacity(0.06), in: Circle())
              }
              .buttonStyle(.plain)
            }

            FlowingMetaRow(items: detailMeta)

            VStack(alignment: .leading, spacing: 8) {
              Text("任务说明")
                .font(.headline.weight(.semibold))
              Text(task.description?.isEmpty == false ? task.description! : "当前没有补充描述。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Button {
              withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                isSubtasksExpanded.toggle()
              }
            } label: {
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Text("子任务")
                    .font(.headline.weight(.semibold))
                  Spacer()
                  if !orderedSteps.isEmpty {
                    Text(isSubtasksExpanded ? "收起" : "展开")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.secondary)
                  }
                  Image(systemName: isSubtasksExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                }

                if orderedSteps.isEmpty {
                  Text("暂无子任务")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                  Text("最新进展")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                  ForEach(visibleSteps) { step in
                    VStack(alignment: .leading, spacing: 4) {
                      Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                      Text("估时 \(step.estimatedMinutes) 分钟，最小块 \(step.minChunkMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                  }
                }
              }
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                  .fill(Color.black.opacity(0.03))
              )
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
              Button(task.status == .done ? "标为待办" : "完成", action: onToggleDone)
                .buttonStyle(.borderedProminent)
                .tint(task.status == .done ? Color.gray : task.status.accentColor)

              Button("编辑", action: onEdit)
                .buttonStyle(.bordered)

              Button("归档", role: .destructive, action: onArchive)
                .buttonStyle(.bordered)
            }
          }
          .padding(20)
          .padding(.bottom, 12)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(maxHeight: 560)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 34, style: .continuous)
          .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
      )
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
      .shadow(color: Color.black.opacity(0.22), radius: 30, y: 16)
    }
  }

  private var detailMeta: [String] {
    var items = [
      "估时 \(task.estimatedMinutes) 分钟",
      "最小块 \(task.minChunkMinutes) 分钟"
    ]
    if let dueLabel = AppFormatters.dueLabel(for: task.dueAt) {
      items.append(dueLabel)
    }
    if !task.tags.isEmpty {
      items.append(task.tags.map { "#\($0)" }.joined(separator: " "))
    }
    return items
  }
}

private struct FlowingMetaRow: View {
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(items.chunked(into: 2), id: \.self) { row in
        HStack(spacing: 8) {
          ForEach(row, id: \.self) { item in
            Text(item)
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color.black.opacity(0.05), in: Capsule())
          }
          Spacer(minLength: 0)
        }
      }
    }
  }
}

private extension Array where Element == String {
  func chunked(into size: Int) -> [[String]] {
    guard size > 0 else { return [self] }

    var result: [[String]] = []
    var index = 0
    while index < count {
      let end = Swift.min(index + size, count)
      result.append(Array(self[index..<end]))
      index += size
    }
    return result
  }
}
