import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable var store: NornAppStore

  @FocusState private var dockFocused: Bool
  @State private var reservedDockHeight: CGFloat = 60

  var body: some View {
    TabView(selection: $store.currentTab) {
      SequenceTab(tasks: store.visibleTasks) { task in
        store.openTaskDetail(taskID: task.id)
      }
        .safeAreaPadding(.bottom, reservedDockHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissDockFocus)
        .tag(AppTab.sequence)

      ScheduleTab()
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissDockFocus)
        .tag(AppTab.schedule)

      TaskPoolTab()
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
}

#Preview {
  ContentView(store: .preview())
}
