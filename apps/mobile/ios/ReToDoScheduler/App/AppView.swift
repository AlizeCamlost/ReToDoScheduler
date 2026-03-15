import SwiftUI

struct AppView: View {
  @StateObject private var viewModel = AppViewModel()

  var body: some View {
    NavigationStack {
      List {
        QuickAddSection(
          input: $viewModel.input,
          syncMessage: viewModel.syncMessage,
          isSyncing: viewModel.isSyncing,
          onAdd: { _Concurrency.Task { await viewModel.addTask() } },
          onSync: { _Concurrency.Task { await viewModel.syncNow() } }
        )

        ScheduleSection(
          horizon: $viewModel.horizon,
          scheduleView: viewModel.scheduleView,
          groupedBlocks: viewModel.groupedBlocks,
          titleForBlock: viewModel.taskTitle(for:)
        )

        TaskPoolSection(
          searchQuery: $viewModel.searchQuery,
          tasks: viewModel.filteredTasks,
          onCreateDetailedTask: viewModel.openCreateTaskEditor,
          onToggleDone: { task in _Concurrency.Task { await viewModel.toggleDone(task) } },
          onArchive: { task in _Concurrency.Task { await viewModel.archive(task) } },
          onEdit: viewModel.openEditor
        )
      }
      .listStyle(.insetGrouped)
      .navigationTitle("任务池")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            viewModel.showingSettings = true
          } label: {
            Image(systemName: "gearshape")
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
