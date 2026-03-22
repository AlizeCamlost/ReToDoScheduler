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
  let syncStatus: SyncStatus
  let onOpenSyncSettings: () -> Void
  let onRefresh: () -> Void

  init(
    syncStatus: SyncStatus = .notConfigured,
    onOpenSyncSettings: @escaping () -> Void = {},
    onRefresh: @escaping () -> Void = {}
  ) {
    self.syncStatus = syncStatus
    self.onOpenSyncSettings = onOpenSyncSettings
    self.onRefresh = onRefresh
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
      VStack {
        Spacer(minLength: 120)
        Text("任务池视图开发中")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
        Spacer(minLength: 120)
      }
      .frame(maxWidth: .infinity)
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
}

#Preview {
  TaskPoolTab(syncStatus: .idle(lastSyncedAt: Date()))
}
