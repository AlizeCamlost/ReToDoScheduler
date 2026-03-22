import SwiftUI

struct QuickAddDock: View {
  @Binding var input: String
  @FocusState.Binding var isFocused: Bool
  let onAdd: () -> Void

  private var trimmedInput: String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var submitEnabled: Bool {
    !trimmedInput.isEmpty
  }

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
            .foregroundStyle(submitEnabled ? Color.white : Color.secondary)
            .frame(width: 36, height: 36)
            .background(
              Circle().fill(submitEnabled ? Color.accentColor : NornTheme.pillSurfaceStrong)
            )
        }
        .buttonStyle(.plain)
        .disabled(!submitEnabled)
        .transition(.scale(scale: 0.7, anchor: .trailing).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(
      Capsule()
        .fill(NornTheme.cardSurface)
        .shadow(color: NornTheme.shadow, radius: 20, y: 8)
    )
    .overlay(
      Capsule()
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
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
