import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable var store: NornAppStore

  @FocusState private var dockFocused: Bool

  private let quickAddDockMaxHeight: CGFloat = 64
  private let quickAddDockBottomSpacing: CGFloat = 8

  var body: some View {
    GeometryReader { proxy in
      let sequenceDockBottomReserve = sequenceDockReserve(bottomInset: proxy.safeAreaInsets.bottom)

      ZStack(alignment: .bottom) {
        NornScreenBackground()

        TabView(selection: $store.currentTab) {
          SequenceTab(
            tasks: store.visibleTasks,
            bottomAccessoryHeight: store.currentTab == .sequence ? sequenceDockBottomReserve : 0,
            onTaskTap: { task in
              store.openTaskDetail(taskID: task.id)
            },
            onPrimarySequenceReorder: { reorderedTaskIDs in
              store.reorderPrimarySequence(taskIDs: reorderedTaskIDs)
            }
          )
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
        .background(Color.clear)
        .ignoresSafeArea(.container, edges: [.bottom, .horizontal])

        if store.currentTab == .sequence {
          QuickAddDock(
            input: $store.quickAddInput,
            isFocused: $dockFocused,
            onAdd: submitQuickAdd
          )
          .padding(.bottom, proxy.safeAreaInsets.bottom + quickAddDockBottomSpacing)
        }
      }
    }
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

  private func sequenceDockReserve(bottomInset: CGFloat) -> CGFloat {
    quickAddDockMaxHeight + bottomInset + quickAddDockBottomSpacing
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
