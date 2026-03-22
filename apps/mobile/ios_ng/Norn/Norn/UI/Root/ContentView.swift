import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase

  let tasks: [Task]
  @State private var currentTab: AppTab = .sequence
  @State private var quickAddInput = ""
  @FocusState private var dockFocused: Bool
  @State private var reservedDockHeight: CGFloat = 60

  init(tasks: [Task] = []) {
    self.tasks = tasks
  }

  var body: some View {
    TabView(selection: $currentTab) {
      SequenceTab(tasks: tasks)
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
      if currentTab == .sequence {
        QuickAddDock(
          input: $quickAddInput,
          isFocused: $dockFocused,
          onAdd: dismissDockFocus
        )
        .padding(.bottom, 8)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
          guard height > 0 else { return }
          reservedDockHeight = height
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentTab)
    .onChange(of: currentTab) { _, _ in
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
}

#Preview {
  ContentView(tasks: NornPreviewFixtures.tasks)
}
