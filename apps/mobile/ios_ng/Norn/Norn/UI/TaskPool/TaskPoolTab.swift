import SwiftUI

enum PoolViewMode: String, CaseIterable, Identifiable {
  case list, quadrant, cluster
  var id: String { rawValue }
  var label: String {
    switch self {
    case .list:     return "列表"
    case .quadrant: return "四象限"
    case .cluster:  return "聚类"
    }
  }
}

struct TaskPoolTab: View {
  @State private var viewMode: PoolViewMode = .list
  let tasks: [Task]
  let syncStatus: SyncStatus
  let onOpenSyncSettings: () -> Void
  let onRefresh: () -> Void
  let onTaskTap: (Task) -> Void

  init(
    tasks: [Task] = [],
    syncStatus: SyncStatus = .notConfigured,
    onOpenSyncSettings: @escaping () -> Void = {},
    onRefresh: @escaping () -> Void = {},
    onTaskTap: @escaping (Task) -> Void = { _ in }
  ) {
    self.tasks = tasks
    self.syncStatus = syncStatus
    self.onOpenSyncSettings = onOpenSyncSettings
    self.onRefresh = onRefresh
    self.onTaskTap = onTaskTap
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      EdgeFadeDivider()
      placeholder
    }
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
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 16)
  }

  private var placeholder: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        switch viewMode {
        case .list:
          listContent
        case .quadrant:
          placeholderCard(
            title: "四象限视图暂未接通",
            message: "本轮先把列表模式接到真实任务数据，象限划分留到下一轮明确规则后再接。"
          )
        case .cluster:
          placeholderCard(
            title: "聚类视图暂未接通",
            message: "聚类依赖额外分组规则和交互，本轮保留占位，不伪造结果。"
          )
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity)
    }
  }

  private var listContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      if tasks.isEmpty {
        placeholderCard(
          title: "任务池为空",
          message: "Quick Add、新建表单或同步回来的任务都会出现在这里。"
        )
      } else {
        ForEach(tasks) { task in
          TaskCard(task: task, dimmed: task.status == .done) {
            onTaskTap(task)
          }
        }
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

  private func placeholderCard(title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(message)
        .font(.caption)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color.primary.opacity(0.04))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    )
  }
}

#Preview {
  TaskPoolTab(
    tasks: NornPreviewFixtures.tasks,
    syncStatus: .idle(lastSyncedAt: Date())
  )
}
