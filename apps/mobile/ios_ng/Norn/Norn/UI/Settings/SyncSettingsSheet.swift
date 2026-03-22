import SwiftUI

struct SyncSettingsSheet: View {
  let syncStatus: SyncStatus
  let onSave: (SyncSettings) -> Void
  let onCancel: () -> Void

  @State private var settings: SyncSettings

  init(
    settings: SyncSettings,
    syncStatus: SyncStatus,
    onSave: @escaping (SyncSettings) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.syncStatus = syncStatus
    self.onSave = onSave
    self.onCancel = onCancel
    _settings = State(initialValue: settings)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("连接信息") {
          TextField("API Base URL", text: $settings.baseURL)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          SecureField("API Auth Token", text: $settings.authToken)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          TextField("Device ID（留空自动生成）", text: $settings.deviceID)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }

        Section("当前状态") {
          Text(statusText)
            .foregroundStyle(statusColor)

          if !settings.isConfigured {
            Text("填写 Base URL 和 Auth Token 后即可启用手动同步。")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("同步设置")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("取消", action: onCancel)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button("保存") {
            onSave(settings)
          }
        }
      }
    }
  }

  private var statusText: String {
    switch syncStatus {
    case .notConfigured:
      return "尚未配置同步。"
    case .syncing:
      return "正在同步…"
    case .failed(let message):
      return message
    case .idle(let lastSyncedAt):
      guard let lastSyncedAt else {
        return "同步配置已保存。"
      }
      return "上次同步 \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))"
    }
  }

  private var statusColor: Color {
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
  SyncSettingsSheet(
    settings: .empty,
    syncStatus: .notConfigured,
    onSave: { _ in },
    onCancel: {}
  )
}
