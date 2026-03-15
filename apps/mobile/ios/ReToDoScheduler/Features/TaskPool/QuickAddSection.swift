import SwiftUI

struct QuickAddSection: View {
  @Binding var input: String
  let syncMessage: String
  let isSyncing: Bool
  let onAdd: () -> Void
  let onSync: () -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 12) {
        Text("动态调度视图会基于当前任务池和时间模板实时重算。")
          .font(.footnote)
          .foregroundStyle(.secondary)

        TextField("输入任务，例如：周报 90分钟 明天 #工作", text: $input, axis: .vertical)
          .textFieldStyle(.roundedBorder)

        HStack {
          Button("添加任务", action: onAdd)
            .buttonStyle(.borderedProminent)

          Spacer()

          Button(isSyncing ? "同步中" : "立即同步", action: onSync)
            .buttonStyle(.bordered)
            .disabled(isSyncing)
        }

        Text(syncMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
  }
}
