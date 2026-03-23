import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable var store: NornAppStore

  @FocusState private var dockFocused: Bool
  @State private var reservedDockHeight: CGFloat = 60

  var body: some View {
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
        .safeAreaPadding(.bottom, reservedDockHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissDockFocus)
        .tag(AppTab.sequence)

      ScheduleTab()
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
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissDockFocus)
        .tag(AppTab.taskPool)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .ignoresSafeArea()
    .simultaneousGesture(
      DragGesture(minimumDistance: 12).onChanged { _ in
        dismissDockFocus()
      }
    )
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if store.currentTab == .sequence {
        QuickAddDock(
          input: $store.quickAddInput,
          isFocused: $dockFocused,
          onAdd: submitQuickAdd
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

#Preview {
  ContentView(store: .preview())
}
