import SwiftUI

struct QuickAddDock: View {
  @Binding var input: String
  @FocusState.Binding var isFocused: Bool
  let onAdd: () -> Void
  let onOpenDetail: () -> Void

  init(
    input: Binding<String>,
    isFocused: FocusState<Bool>.Binding,
    onAdd: @escaping () -> Void,
    onOpenDetail: @escaping () -> Void = {}
  ) {
    _input = input
    _isFocused = isFocused
    self.onAdd = onAdd
    self.onOpenDetail = onOpenDetail
  }

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
        Button(action: onOpenDetail) {
          HStack(spacing: 6) {
            Image(systemName: "note.text")
              .font(.system(size: 14, weight: .semibold))
            Text("详情")
              .font(.subheadline.weight(.semibold))
          }
          .foregroundStyle(.primary)
          .frame(height: 36)
          .padding(.horizontal, 12)
          .background(
            Capsule().fill(NornTheme.pillSurfaceStrong)
          )
        }
        .buttonStyle(.plain)

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
    QuickAddDock(input: $input, isFocused: $focused, onAdd: {}, onOpenDetail: {})
  }
}

#Preview {
  QuickAddDockPreview()
}
