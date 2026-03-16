import SwiftUI

struct AppView: View {
  @StateObject private var viewModel = AppViewModel()
  @FocusState private var isInputFocused: Bool

  var body: some View {
    NavigationStack {
      List {
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

        ScheduleSection(
          horizon: $viewModel.horizon,
          scheduleView: viewModel.scheduleView,
          groupedBlocks: viewModel.groupedBlocks,
          titleForBlock: viewModel.taskTitle(for:)
        )

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
          onEdit: { task in
            isInputFocused = false
            viewModel.openEditor(for: task)
          }
        )
      }
      .listStyle(.insetGrouped)
      .scrollDismissesKeyboard(.interactively)
      .simultaneousGesture(
        TapGesture().onEnded {
          isInputFocused = false
        }
      )
      .navigationTitle("任务池")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isInputFocused = false
            viewModel.showingSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()

          Button("完成") {
            isInputFocused = false
          }
        }
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
        await viewModel.bootstrap()
      }
      .refreshable {
        await viewModel.syncNow()
      }
    }
  }
}
