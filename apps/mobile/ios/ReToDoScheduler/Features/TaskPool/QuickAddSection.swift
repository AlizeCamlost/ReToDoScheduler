import SwiftUI

struct QuickAddSection: View {
  @Binding var input: String
  var keyboardFocus: FocusState<Bool>.Binding
  let syncMessage: String
  let isSyncing: Bool
  let onAdd: () -> Void
  let onSync: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("快速添加")
            .font(.headline.weight(.semibold))
          Text(syncMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()

        Button(isSyncing ? "同步中" : "同步", action: onSync)
          .font(.subheadline.weight(.medium))
          .buttonStyle(.bordered)
          .disabled(isSyncing)
      }

      HStack(alignment: .bottom, spacing: 12) {
        TextField("输入任务，例如：周报 90分钟 明天 #工作", text: $input, axis: .vertical)
          .focused(keyboardFocus)
          .submitLabel(.done)
          .lineLimit(1 ... 3)
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .fill(Color.white.opacity(0.7))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
          )
          .onSubmit(onAdd)

        Button(action: onAdd) {
          Image(systemName: "arrow.up")
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.black.opacity(0.88), Color.black.opacity(0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            )
        }
        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
      }

      Text("输入后直接回车或点击右侧按钮创建任务。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.16), radius: 22, y: 10)
  }
}
