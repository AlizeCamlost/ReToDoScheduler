import SwiftUI

struct ContentView: View {
  @State private var currentTab: AppTab = .sequence
  @State private var quickAddInput = ""
  @FocusState private var dockFocused: Bool
  @State private var reservedDockHeight: CGFloat = 60

  private let tasks = Fixtures.tasks

  var body: some View {
    TabView(selection: $currentTab) {
      SequenceTab(tasks: tasks)
        .safeAreaPadding(.bottom, reservedDockHeight)
        .tag(AppTab.sequence)

      ScheduleTab()
        .tag(AppTab.schedule)

      TaskPoolTab()
        .tag(AppTab.taskPool)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .ignoresSafeArea()
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if currentTab == .sequence {
        QuickAddDock(
          input: $quickAddInput,
          isFocused: $dockFocused,
          onAdd: {}
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
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("完成") { dockFocused = false }
      }
    }
  }
}

#Preview {
  ContentView()
}
