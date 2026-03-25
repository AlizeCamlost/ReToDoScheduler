import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Bindable var store: NornAppStore

  @FocusState private var dockFocused: Bool
  @State private var reservedDockHeight: CGFloat = 60

  var body: some View {
    ZStack {
      NornScreenBackground()

      TabView(selection: $store.currentTab) {
        SequenceTab(
          tasks: store.visibleTasks,
          onTaskTap: { task in
            store.openTaskDetail(taskID: task.id)
          },
          onPrimarySequenceReorder: { reorderedTaskIDs in
            store.reorderPrimarySequence(taskIDs: reorderedTaskIDs)
          }
        )
          .safeAreaPadding(sequenceContentAvoidanceEdges)
          .safeAreaPadding(.bottom, reservedDockHeight)
          .contentShape(Rectangle())
          .onTapGesture(perform: dismissDockFocus)
          .tag(AppTab.sequence)

        ScheduleTab()
          .safeAreaPadding(pageContentAvoidanceEdges)
          .contentShape(Rectangle())
          .onTapGesture(perform: dismissDockFocus)
          .tag(AppTab.schedule)

        TaskPoolTab(
          tasks: store.visibleTasks,
          syncStatus: store.syncStatus,
          onOpenSyncSettings: {
            store.openSyncSettings()
          },
          onRefresh: {
            store.refresh()
          },
          onTaskTap: { task in
            store.openTaskDetail(taskID: task.id)
          }
        )
          .safeAreaPadding(pageContentAvoidanceEdges)
          .contentShape(Rectangle())
          .onTapGesture(perform: dismissDockFocus)
          .tag(AppTab.taskPool)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .background(Color.clear)
      .ignoresSafeArea()
    }
    .overlay(alignment: .top) {
      if store.currentTab == .sequence {
        SequenceSafeAreaScrim(edge: .top)
          .ignoresSafeArea(edges: .top)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if store.currentTab == .sequence {
        QuickAddDock(
            input: $store.quickAddInput,
            isFocused: $dockFocused,
            onAdd: submitQuickAdd,
            onOpenDetail: openQuickAddDetail
        )
        .padding(.bottom, 8)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
          guard height > 0 else { return }
          reservedDockHeight = height
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.currentTab)
    .task {
      store.bootstrap()
    }
    .sheet(isPresented: detailSheetPresented) {
      if let task = store.selectedTask {
        TaskDetailSheet(
          task: task,
          onToggleCompletion: {
            store.toggleTaskCompletion(taskID: task.id)
          },
          onArchive: {
            store.archiveTask(taskID: task.id)
          },
          onEdit: {
            store.openTaskEditor(taskID: task.id)
          },
          onPromoteToDoing: {
            store.updateTaskStatus(taskID: task.id, status: .doing)
          },
          onAddStep: { title in
            store.appendTaskStep(taskID: task.id, title: title)
          },
          currentStepID: task.currentStep?.id,
          onCurrentStepTap: { step in
            store.completeTaskStep(taskID: task.id, stepID: step.id)
          }
        )
      }
    }
    .sheet(isPresented: editorSheetPresented) {
      if let draft = store.taskDraft {
        TaskEditorSheet(
          draft: draft,
          allTasks: store.tasks,
          onSave: { updatedDraft in
            store.saveTaskDraft(updatedDraft)
          },
          onCancel: {
            store.closeTaskEditor()
          }
        )
      }
    }
    .sheet(isPresented: syncSettingsSheetPresented) {
      SyncSettingsSheet(
        settings: store.syncSettings,
        syncStatus: store.syncStatus,
        onSave: { settings in
          store.saveSyncSettings(settings)
        },
        onCancel: {
          store.closeSyncSettings()
        }
      )
    }
    .onChange(of: store.currentTab) { _, _ in
      dismissDockFocus()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        dismissDockFocus()
      }
    }
  }

  private func dismissDockFocus() {
    guard dockFocused else { return }
    dockFocused = false
  }

  private func submitQuickAdd() {
    store.submitQuickAdd()
    dismissDockFocus()
  }

  private func openQuickAddDetail() {
    store.openNewTaskDraftFromQuickAdd()
    dismissDockFocus()
  }

  private var isLandscapeLike: Bool {
    verticalSizeClass == .compact
  }

  private var pageContentAvoidanceEdges: Edge.Set {
    isLandscapeLike ? .horizontal : .vertical
  }

  private var sequenceContentAvoidanceEdges: Edge.Set {
    isLandscapeLike ? .horizontal : .top
  }

  private var detailSheetPresented: Binding<Bool> {
    Binding(
      get: { store.selectedTask != nil },
      set: { presented in
        if !presented {
          store.closeTaskDetail()
        }
      }
    )
  }

  private var editorSheetPresented: Binding<Bool> {
    Binding(
      get: { store.taskDraft != nil },
      set: { presented in
        if !presented {
          store.closeTaskEditor()
        }
      }
    )
  }

  private var syncSettingsSheetPresented: Binding<Bool> {
    Binding(
      get: { store.isSyncSettingsPresented },
      set: { presented in
        if !presented {
          store.closeSyncSettings()
        }
      }
    )
  }
}

private struct SequenceSafeAreaScrim: View {
  let edge: VerticalEdge

  var body: some View {
    LinearGradient(
      stops: gradientStops,
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: edge == .top ? 120 : 30)
    .frame(maxWidth: .infinity)
    .allowsHitTesting(false)
  }

  private var gradientStops: [Gradient.Stop] {
    switch edge {
    case .top:
      return [
        .init(color: NornTheme.canvasTop.opacity(0.98), location: 0),
        .init(color: NornTheme.canvasTop.opacity(0.68), location: 0.32),
        .init(color: NornTheme.shadow.opacity(0.08), location: 0.66),
        .init(color: .clear, location: 1)
      ]
    case .bottom:
      return [
        .init(color: .clear, location: 0),
        .init(color: NornTheme.shadow.opacity(0.08), location: 0.28),
        .init(color: NornTheme.canvasBottom.opacity(0.68), location: 0.72),
        .init(color: NornTheme.canvasBottom.opacity(0.98), location: 1)
      ]
    }
  }
}

#Preview {
  ContentView(store: .preview())
}
