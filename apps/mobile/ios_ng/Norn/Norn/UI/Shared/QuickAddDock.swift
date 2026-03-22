import SwiftUI

struct QuickAddDock: View {
  @Binding var input: String
  @FocusState.Binding var isFocused: Bool
  let onAdd: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TextField("添加任务…", text: $input)
        .focused($isFocused)
        .submitLabel(.done)
        .onSubmit(onAdd)
        .font(.body)

      if isFocused {
        Button(action: onAdd) {
          Image(systemName: "arrow.up")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
              Circle().fill(input.trimmingCharacters(in: .whitespaces).isEmpty
                ? Color.primary.opacity(0.25)
                : Color.primary)
            )
        }
        .buttonStyle(.plain)
        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        .transition(.scale(scale: 0.7, anchor: .trailing).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(
      Capsule()
        .fill(.regularMaterial)
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    )
    .overlay(
      Capsule()
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .padding(.horizontal, 16)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
  }
}

private struct QuickAddDockPreview: View {
  @State var input = ""
  @FocusState var focused: Bool
  var body: some View {
    QuickAddDock(input: $input, isFocused: $focused, onAdd: {})
  }
}

#Preview {
  QuickAddDockPreview()
}
