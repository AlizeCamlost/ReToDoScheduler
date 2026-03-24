import SwiftUI

struct QuickAddDock: View {
  @Binding var input: String
  @FocusState.Binding var isFocused: Bool
  let onAdd: () -> Void
  let onOpenDetail: () -> Void

  private let cornerRadius: CGFloat = 30

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
      Image(systemName: "plus.circle")
        .font(.title3.weight(.semibold))
        .foregroundStyle(isFocused ? Color.accentColor : .secondary)

      TextField("添加任务…", text: $input)
        .focused($isFocused)
        .textFieldStyle(.plain)
        .submitLabel(.done)
        .onSubmit(onAdd)
        .font(.body)

      if isFocused {
        HStack(spacing: 12) {
          divider

          Button(action: onOpenDetail) {
            HStack(spacing: 6) {
              Image(systemName: "note.text")
                .font(.caption.weight(.semibold))
              Text("详情")
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
          }
          .buttonStyle(.plain)

          divider

          Button(action: onAdd) {
            Image(systemName: submitEnabled ? "arrow.up.circle.fill" : "arrow.up.circle")
              .font(.title2)
              .foregroundStyle(submitEnabled ? Color.accentColor : .secondary)
          }
          .buttonStyle(.plain)
          .disabled(!submitEnabled)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 15)
    .background(
      RoundedRectangle(cornerRadius: cornerRadius + 8, style: .continuous)
        .fill(.ultraThinMaterial)
        .padding(-8)
        .mask(
          RoundedRectangle(cornerRadius: cornerRadius + 8, style: .continuous)
            .stroke(lineWidth: 14)
        )
        .blur(radius: 10)
        .opacity(0.78)
    )
    .background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
        .shadow(color: NornTheme.shadow, radius: 18, y: 8)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(NornTheme.border, lineWidth: 1)
    )
    .padding(.horizontal, 16)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
  }

  private var divider: some View {
    Rectangle()
      .fill(NornTheme.borderStrong)
      .frame(width: 1, height: 26)
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
