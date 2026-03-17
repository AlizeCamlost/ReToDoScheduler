import SwiftUI

enum AppInputFocusTarget: Hashable {
  case taskSearch
  case quickAdd
}

struct AppView: View {
  @StateObject private var viewModel: AppViewModel
  @FocusState private var focusedField: AppInputFocusTarget?
  private let shouldBootstrap: Bool
  @State private var isChromeExpanded = false
  @State private var chromeHeight: CGFloat = 0
  @State private var chromeDragOffset: CGFloat = 0

  @MainActor
  init(shouldBootstrap: Bool = true) {
    _viewModel = StateObject(wrappedValue: AppViewModel())
    self.shouldBootstrap = shouldBootstrap
  }

  @MainActor
  init(viewModel: AppViewModel, shouldBootstrap: Bool = true) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.shouldBootstrap = shouldBootstrap
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppBackdrop(perspective: viewModel.currentPerspective)

        TabView(selection: $viewModel.currentPerspective) {
          taskPoolPage
            .tag(HomePerspective.tasks)

          schedulePage
            .tag(HomePerspective.calendar)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ViewHierarchyClipDisabler())
        .onChange(of: viewModel.currentPerspective) { _ in
          focusedField = nil
          collapseChrome()
        }

        AppChromeHeader(
          currentPerspective: $viewModel.currentPerspective,
          syncMessage: viewModel.syncMessage,
          isSyncing: viewModel.isSyncing,
          onSync: {
            focusedField = nil
            _Concurrency.Task { await viewModel.syncNow() }
          },
          onSettings: {
            focusedField = nil
            viewModel.showingSettings = true
          }
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(
          GeometryReader { geometry in
            Color.clear
              .preference(key: ChromeHeightPreferenceKey.self, value: geometry.size.height)
          }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(y: chromeOffsetY)
        .allowsHitTesting(isChromeInteractive)
        .simultaneousGesture(chromeDragGesture)

        Color.clear
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .overlay(alignment: .top) {
            Color.clear
              .frame(height: 72)
              .contentShape(Rectangle())
              .gesture(chromeDragGesture)
              .allowsHitTesting(!isChromeExpanded)
          }

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
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if viewModel.currentPerspective == .tasks {
          quickAddDock
        }
      }
      .background(ViewHierarchyClipDisabler())
      .toolbar(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()

          Button("完成") {
            focusedField = nil
          }
        }
      }
      .contentShape(Rectangle())
      .simultaneousGesture(
        TapGesture().onEnded {
          focusedField = nil
          collapseChrome()
        }
      )
      .onPreferenceChange(ChromeHeightPreferenceKey.self) { height in
        chromeHeight = height
      }
      .onChange(of: focusedField) { _ in
        collapseChrome()
      }
      .onChange(of: viewModel.showingSettings) { isPresented in
        if isPresented {
          focusedField = nil
          collapseChrome()
        }
      }
      .onChange(of: viewModel.showingTaskEditor) { isPresented in
        if isPresented {
          focusedField = nil
          collapseChrome()
        }
      }
      .onChange(of: viewModel.selectedTaskID) { _ in
        focusedField = nil
        collapseChrome()
      }
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
        guard shouldBootstrap else { return }
        await viewModel.bootstrap()
      }
    }
  }

  private var chromeHiddenDistance: CGFloat {
    max(chromeHeight + 20, 180)
  }

  private var taskPoolPage: some View {
    TaskPoolSection(
      searchQuery: $viewModel.searchQuery,
      keyboardFocus: $focusedField,
      tasks: viewModel.filteredTasks,
      onCreateDetailedTask: {
        focusedField = nil
        viewModel.openCreateTaskEditor()
      },
      onToggleDone: { task in
        focusedField = nil
        _Concurrency.Task { await viewModel.toggleDone(task) }
      },
      onArchive: { task in
        focusedField = nil
        _Concurrency.Task { await viewModel.archive(task) }
      },
      onOpenDetail: { task in
        focusedField = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
          viewModel.openTaskDetail(task)
        }
      },
      onEdit: { task in
        focusedField = nil
        viewModel.openEditor(for: task)
      }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .contentShape(Rectangle())
  }

  private var quickAddDock: some View {
    ZStack(alignment: .bottom) {
      QuickAddDockBackground()

      QuickAddDockSurface(isFocused: focusedField == .quickAdd) {
        QuickAddSection(
          input: $viewModel.input,
          keyboardFocus: $focusedField,
          syncMessage: viewModel.syncMessage,
          isSyncing: viewModel.isSyncing,
          onAdd: {
            focusedField = nil
            _Concurrency.Task { await viewModel.addTask() }
          },
          onSync: {
            focusedField = nil
            _Concurrency.Task { await viewModel.syncNow() }
          }
        )
      }
    }
    .frame(maxWidth: .infinity)
    .background(ViewHierarchyClipDisabler())
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private var schedulePage: some View {
    ScheduleSection(
      calendarMode: $viewModel.calendarMode,
      scheduleView: viewModel.scheduleView,
      titleForBlock: viewModel.taskTitle(for:),
      taskForBlock: viewModel.task(for:),
      taskForID: viewModel.task(for:),
      onSelectTask: { task in
        focusedField = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
          viewModel.openTaskDetail(task)
        }
      }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .contentShape(Rectangle())
  }

  private var chromeOffsetY: CGFloat {
    -chromeHiddenDistance + chromeRevealDistance
  }

  private var chromeRevealDistance: CGFloat {
    rubberBandedChromeRevealDistance(chromeRestingRevealDistance + chromeDragOffset)
  }

  private var chromeRestingRevealDistance: CGFloat {
    isChromeExpanded ? chromeHiddenDistance : 0
  }

  private var isChromeInteractive: Bool {
    isChromeExpanded || abs(chromeDragOffset) > 0.5
  }

  private var chromeDragGesture: some Gesture {
    DragGesture(minimumDistance: 10)
      .onChanged { value in
        chromeDragOffset = value.translation.height
      }
      .onEnded { value in
        let projectedRevealDistance = clampedChromeRevealDistance(
          chromeRestingRevealDistance + value.predictedEndTranslation.height
        )
        let shouldExpand = projectedRevealDistance > (chromeHiddenDistance * 0.45)

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
          isChromeExpanded = shouldExpand
          chromeDragOffset = 0
        }
      }
  }

  private func collapseChrome() {
    withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
      isChromeExpanded = false
      chromeDragOffset = 0
    }
  }

  private func clampedChromeRevealDistance(_ distance: CGFloat) -> CGFloat {
    min(max(distance, 0), chromeHiddenDistance)
  }

  private func rubberBandedChromeRevealDistance(_ distance: CGFloat) -> CGFloat {
    let clampedDistance = clampedChromeRevealDistance(distance)

    if distance > chromeHiddenDistance {
      let overflow = distance - chromeHiddenDistance
      let resistedOverflow = linearlyDampedOverflow(
        overflow,
        initialGain: 0.48,
        dampingPerPoint: 0.010,
        minimumGain: 0.10,
        maxVisibleOverflow: 50
      )
      return chromeHiddenDistance + resistedOverflow
    }

    if distance < 0 {
      let overflow = abs(distance)
      let resistedOverflow = linearlyDampedOverflow(
        overflow,
        initialGain: 0.24,
        dampingPerPoint: 0.012,
        minimumGain: 0.06,
        maxVisibleOverflow: 12
      )
      return -resistedOverflow
    }

    return clampedDistance
  }

  private func linearlyDampedOverflow(
    _ overflow: CGFloat,
    initialGain: CGFloat,
    dampingPerPoint: CGFloat,
    minimumGain: CGFloat,
    maxVisibleOverflow: CGFloat
  ) -> CGFloat {
    guard overflow > 0 else { return 0 }

    let clampedMinimumGain = min(initialGain, minimumGain)
    let slope = max(dampingPerPoint, 0.0001)
    let threshold = max((initialGain - clampedMinimumGain) / slope, 0)
    let linearRegion = min(overflow, threshold)
    let integratedLinearRegion =
      (initialGain * linearRegion) - (0.5 * slope * linearRegion * linearRegion)
    let tailOverflow = max(overflow - threshold, 0)
    let integratedTail = tailOverflow * clampedMinimumGain

    return min(integratedLinearRegion + integratedTail, maxVisibleOverflow)
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
  @Environment(\.colorScheme) private var colorScheme

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
        .fill(accentColor.opacity(colorScheme == .dark ? 0.28 : 0.18))
        .frame(width: 300, height: 300)
        .blur(radius: 16)
        .offset(x: perspective == .tasks ? -120 : 110, y: -250)

      RoundedRectangle(cornerRadius: 80, style: .continuous)
        .fill(floatingCardColor)
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
    switch (perspective, colorScheme) {
    case (.tasks, .light):
      return [
        Color(red: 0.97, green: 0.93, blue: 0.88),
        Color(red: 0.90, green: 0.94, blue: 0.98),
        Color(red: 0.96, green: 0.96, blue: 0.98)
      ]
    case (.calendar, .light):
      return [
        Color(red: 0.90, green: 0.95, blue: 0.99),
        Color(red: 0.84, green: 0.90, blue: 0.98),
        Color(red: 0.94, green: 0.94, blue: 0.98)
      ]
    case (.tasks, .dark):
      return [
        Color(red: 0.16, green: 0.14, blue: 0.13),
        Color(red: 0.12, green: 0.16, blue: 0.20),
        Color(red: 0.09, green: 0.10, blue: 0.12)
      ]
    case (.calendar, .dark):
      return [
        Color(red: 0.10, green: 0.14, blue: 0.18),
        Color(red: 0.08, green: 0.12, blue: 0.18),
        Color(red: 0.08, green: 0.09, blue: 0.12)
      ]
    }
  }

  private var accentColor: Color {
    perspective == .tasks ? Color.orange : Color.blue
  }

  private var floatingCardColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.08)
  }
}

@MainActor
private extension AppViewModel {
  static func preview() -> AppViewModel {
    let viewModel = AppViewModel()
    viewModel.tasks = AppViewPreviewFixtures.tasks
    viewModel.timeTemplate = AppViewPreviewFixtures.timeTemplate
    viewModel.syncMessage = "已同步 3 项，09:41"
    viewModel.apiBaseURL = "http://43.159.136.45:8787"
    viewModel.apiAuthToken = "preview-token"
    viewModel.currentPerspective = .tasks
    viewModel.calendarMode = .week
    return viewModel
  }
}

private enum AppViewPreviewFixtures {
  static let planningTask = Task(
    id: "task-plan-launch",
    title: "准备 TestFlight 发布",
    rawInput: "准备 TestFlight 发布 90分钟 明天 #iOS",
    description: "整理截图、检查隐私说明并完成最后一轮自测。",
    estimatedMinutes: 90,
    minChunkMinutes: 30,
    dueAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
    importance: 5,
    value: 5,
    difficulty: 4,
    postponability: 1,
    taskTraits: TaskTraits(
      focus: .high,
      interruptibility: .low,
      location: .indoor,
      device: .desktop,
      parallelizable: false
    ),
    tags: ["ios", "release"],
    scheduleValue: TaskValueSpec(rewardOnTime: 18, penaltyMissed: 40),
    steps: [
      TaskStepTemplate(
        id: "screenshots",
        title: "更新商店截图",
        estimatedMinutes: 30,
        minChunkMinutes: 15,
        dependsOnStepIds: []
      ),
      TaskStepTemplate(
        id: "privacy",
        title: "核对隐私配置",
        estimatedMinutes: 20,
        minChunkMinutes: 10,
        dependsOnStepIds: ["screenshots"]
      )
    ]
  )

  static let syncTask = Task(
    id: "task-sync-debug",
    title: "排查同步报错",
    rawInput: "排查同步报错 45分钟 今天 #后端",
    description: "检查 token、容器端口和 API 健康状态。",
    status: .doing,
    estimatedMinutes: 45,
    minChunkMinutes: 15,
    dueAt: Date(),
    importance: 4,
    value: 4,
    difficulty: 3,
    postponability: 2,
    taskTraits: TaskTraits(
      focus: .medium,
      interruptibility: .medium,
      location: .indoor,
      device: .desktop,
      parallelizable: false
    ),
    tags: ["backend", "sync"],
    scheduleValue: TaskValueSpec(rewardOnTime: 12, penaltyMissed: 20)
  )

  static let cleanupTask = Task(
    id: "task-cleanup",
    title: "清理旧构建产物",
    rawInput: "清理旧构建产物 20分钟 #维护",
    description: "移除不再使用的预览资源和缓存。",
    status: .done,
    estimatedMinutes: 20,
    minChunkMinutes: 10,
    importance: 2,
    value: 2,
    difficulty: 1,
    postponability: 5,
    taskTraits: TaskTraits(
      focus: .low,
      interruptibility: .high,
      location: .indoor,
      device: .desktop,
      parallelizable: true
    ),
    tags: ["maintain"]
  )

  static let tasks: [Task] = [
    planningTask,
    syncTask,
    cleanupTask
  ]

  static let timeTemplate = TimeTemplate(
    timezone: TimeZone.current.identifier,
    weeklyRanges: [
      WeeklyTimeRange(id: "1-morning", weekday: 1, startTime: "09:00", endTime: "12:00"),
      WeeklyTimeRange(id: "1-afternoon", weekday: 1, startTime: "14:00", endTime: "18:00"),
      WeeklyTimeRange(id: "2-morning", weekday: 2, startTime: "09:30", endTime: "12:30")
    ]
  )
}

#Preview("App Home") {
  AppView(viewModel: .preview(), shouldBootstrap: false)
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

private struct ChromeHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct ViewHierarchyClipDisabler: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
      var current: UIView? = uiView
      var topmostView: UIView?

      while let view = current {
        view.clipsToBounds = false
        view.layer.masksToBounds = false
        topmostView = view
        current = view.superview
      }

      if let topmostView {
        disableClippingRecursively(in: topmostView)
      }

      if let window = uiView.window {
        window.clipsToBounds = false
        window.layer.masksToBounds = false
      }
    }
  }

  private func disableClippingRecursively(in view: UIView) {
    view.clipsToBounds = false
    view.layer.masksToBounds = false

    for subview in view.subviews {
      disableClippingRecursively(in: subview)
    }
  }
}

private struct QuickAddDockBackground: View {
  private let dockInset: CGFloat = 10

  var body: some View {
    GeometryReader { geometry in
      let bottomInset = max(geometry.safeAreaInsets.bottom, dockInset)

      ContainerRelativeShape()
      .inset(by: dockInset)
      .fill(.ultraThinMaterial)
      .overlay(
        ContainerRelativeShape()
          .inset(by: dockInset)
          .strokeBorder(Color.white.opacity(0.58), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.12), radius: 26, y: 8)
      .frame(height: 92 + bottomInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      .ignoresSafeArea(edges: .bottom)
    }
    .frame(height: 124)
  }
}

private struct QuickAddDockSurface<Content: View>: View {
  let isFocused: Bool
  @ViewBuilder let content: () -> Content

  private let surfaceInset: CGFloat = 30
  private let dockInset: CGFloat = 30

  var body: some View {
    GeometryReader { geometry in
      let bottomInset = max(geometry.safeAreaInsets.bottom, dockInset)

      ContainerRelativeShape()
        .inset(by: surfaceInset)
        .fill(Color.white.opacity(isFocused ? 0.94 : 0.88))
        .overlay(
          ContainerRelativeShape()
            .inset(by: surfaceInset)
            .strokeBorder(Color.white.opacity(isFocused ? 0.94 : 0.84), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isFocused ? 0.10 : 0.07), radius: isFocused ? 24 : 18, y: 8)
        .frame(height: 92 + bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .overlay {
          content()
            .scaleEffect(isFocused ? 1.01 : 1, anchor: .center)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    .frame(height: 124)
    .animation(.spring(response: 0.30, dampingFraction: 0.82), value: isFocused)
  }
}

extension View {
  @ViewBuilder
  func appScrollOverflowVisible() -> some View {
    if #available(iOS 17.0, *) {
      self.scrollClipDisabled()
    } else {
      self
    }
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
