import SwiftUI

struct TaskPoolTab: View {
  let tasks: [Task]
  let organization: TaskPoolOrganizationDocument
  let syncStatus: SyncStatus
  let onOpenSyncSettings: () -> Void
  let onRefresh: () -> Void
  let onTaskTap: (Task) -> Void
  let onCreateDirectory: (String, String?) -> Void
  let onRenameDirectory: (String, String) -> Void
  let onDeleteDirectory: (String) -> Void
  let onMoveDirectory: (String, String?) -> Void
  let onMoveTask: (String, String?) -> Void

  init(
    tasks: [Task] = [],
    organization: TaskPoolOrganizationDocument = .defaultValue(),
    syncStatus: SyncStatus = .notConfigured,
    onOpenSyncSettings: @escaping () -> Void = {},
    onRefresh: @escaping () -> Void = {},
    onTaskTap: @escaping (Task) -> Void = { _ in },
    onCreateDirectory: @escaping (String, String?) -> Void = { _, _ in },
    onRenameDirectory: @escaping (String, String) -> Void = { _, _ in },
    onDeleteDirectory: @escaping (String) -> Void = { _ in },
    onMoveDirectory: @escaping (String, String?) -> Void = { _, _ in },
    onMoveTask: @escaping (String, String?) -> Void = { _, _ in }
  ) {
    self.tasks = tasks
    self.organization = organization
    self.syncStatus = syncStatus
    self.onOpenSyncSettings = onOpenSyncSettings
    self.onRefresh = onRefresh
    self.onTaskTap = onTaskTap
    self.onCreateDirectory = onCreateDirectory
    self.onRenameDirectory = onRenameDirectory
    self.onDeleteDirectory = onDeleteDirectory
    self.onMoveDirectory = onMoveDirectory
    self.onMoveTask = onMoveTask
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      EdgeFadeDivider()
      placeholder
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.clear)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("任务池")
            .font(.title2.weight(.bold))
          Text(syncStatusText)
            .font(.caption)
            .foregroundStyle(syncStatusColor)
        }

        Spacer()

        HStack(spacing: 10) {
          Button(action: onRefresh) {
            Image(systemName: syncStatus == .syncing ? "arrow.trianglehead.2.clockwise.circle.fill" : "arrow.clockwise.circle")
              .font(.title3)
          }
          .buttonStyle(.plain)
          .foregroundStyle(syncStatusColor)
          .disabled(syncStatus == .syncing)

          Button(action: onOpenSyncSettings) {
            Image(systemName: "slider.horizontal.3")
              .font(.title3)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.primary)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 16)
  }

  private var placeholder: some View {
    TaskPoolTreeBrowser(
      tasks: tasks,
      organization: organization,
      onTaskTap: onTaskTap,
      onCreateDirectory: onCreateDirectory,
      onRenameDirectory: onRenameDirectory,
      onDeleteDirectory: onDeleteDirectory,
      onMoveDirectory: onMoveDirectory,
      onMoveTask: onMoveTask
    )
  }

  private var syncStatusText: String {
    switch syncStatus {
    case .notConfigured:
      return "未配置同步，当前使用本地任务仓库。"
    case .syncing:
      return "正在同步任务池…"
    case .failed(let message):
      return message
    case .idle(let lastSyncedAt):
      guard let lastSyncedAt else {
        return "已配置同步，可手动刷新。"
      }
      return "上次同步 \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))"
    }
  }

  private var syncStatusColor: Color {
    switch syncStatus {
    case .failed:
      return .red
    case .syncing:
      return .blue
    case .notConfigured:
      return .secondary
    case .idle:
      return .secondary
    }
  }
}

#Preview {
  TaskPoolTab(
    tasks: NornPreviewFixtures.tasks,
    organization: NornPreviewFixtures.taskPoolOrganization,
    syncStatus: .idle(lastSyncedAt: Date())
  )
}
