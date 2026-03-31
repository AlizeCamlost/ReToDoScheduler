import SwiftUI

enum PoolViewMode: String, CaseIterable, Identifiable {
  case tree
  case canvas

  var id: String { rawValue }

  var label: String {
    switch self {
    case .tree:
      return "目录树"
    case .canvas:
      return "画布"
    }
  }
}

struct TaskPoolTab: View {
  @State private var viewMode: PoolViewMode = .tree
  @AppStorage("norn.taskPool.hideCompletedTasks") private var hideCompletedTasks = false

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
  let onUpdateCanvasNode: (String, TaskPoolCanvasNodeLayout.NodeKind, Double, Double, Bool) -> Void
  let onResetCanvasLayout: () -> Void

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
    onMoveTask: @escaping (String, String?) -> Void = { _, _ in },
    onUpdateCanvasNode: @escaping (String, TaskPoolCanvasNodeLayout.NodeKind, Double, Double, Bool) -> Void = { _, _, _, _, _ in },
    onResetCanvasLayout: @escaping () -> Void = {}
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
    self.onUpdateCanvasNode = onUpdateCanvasNode
    self.onResetCanvasLayout = onResetCanvasLayout
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

  private var filteredTasks: [Task] {
    TaskPoolVisibleTasks.filtered(tasks, hideCompleted: hideCompletedTasks)
  }

  private var hiddenCompletedTaskCount: Int {
    TaskPoolVisibleTasks.filtered(tasks, hideCompleted: false).count - filteredTasks.count
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

      Picker("", selection: $viewMode) {
        ForEach(PoolViewMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      Toggle(isOn: $hideCompletedTasks) {
        VStack(alignment: .leading, spacing: 2) {
          Text("隐藏已完成任务")
            .font(.caption.weight(.semibold))

          if hideCompletedTasks, hiddenCompletedTaskCount > 0 {
            Text("当前已从任务池隐藏 \(hiddenCompletedTaskCount) 个已完成任务。")
              .font(.caption2)
              .foregroundStyle(.secondary)
          } else {
            Text(hideCompletedTasks ? "任务池当前只显示未归档且未完成的任务。" : "任务池当前显示全部未归档任务。")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
      .toggleStyle(.switch)
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 16)
  }

  @ViewBuilder
  private var placeholder: some View {
    switch viewMode {
    case .tree:
      TaskPoolTreeBrowser(
        tasks: filteredTasks,
        organization: organization,
        onTaskTap: onTaskTap,
        onCreateDirectory: onCreateDirectory,
        onRenameDirectory: onRenameDirectory,
        onDeleteDirectory: onDeleteDirectory,
        onMoveDirectory: onMoveDirectory,
        onMoveTask: onMoveTask
      )
    case .canvas:
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          canvasIntroCard
          TaskPoolCanvasView(
            tasks: filteredTasks,
            organization: organization,
            onTaskTap: onTaskTap,
            onUpdateNode: onUpdateCanvasNode,
            onResetLayout: onResetCanvasLayout
          )
          .frame(minHeight: 720)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
      }
    }
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

  private var canvasIntroCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("画布视图")
        .font(.headline.weight(.semibold))
      Text(hideCompletedTasks
        ? "拖拽目录或任务节点会直接更新共享的任务池组织文档，折叠状态也会随同步保留。已完成任务当前会从画布隐藏；同时支持双指缩放和右上角缩放控件。"
        : "拖拽目录或任务节点会直接更新共享的任务池组织文档，折叠状态也会随同步保留；同时支持双指缩放和右上角缩放控件。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }
}

#Preview {
  TaskPoolTab(
    tasks: NornPreviewFixtures.tasks,
    organization: NornPreviewFixtures.taskPoolOrganization,
    syncStatus: .idle(lastSyncedAt: Date())
  )
}
