import SwiftUI

enum QuickAddDockLayout {
  static let minHeight: CGFloat = 56
  static let bottomSpacing: CGFloat = 8
  static let reserveHeight: CGFloat = 68
}

struct QuickAddDock: View {
  @Binding var input: String
  @FocusState.Binding var isFocused: Bool
  let onAdd: () -> Void
  let onOpenDetail: () -> Void
  let onOpenSequence: () -> Void

  private let cornerRadius: CGFloat = 30

  init(
    input: Binding<String>,
    isFocused: FocusState<Bool>.Binding,
    onAdd: @escaping () -> Void,
    onOpenDetail: @escaping () -> Void = {},
    onOpenSequence: @escaping () -> Void = {}
  ) {
    _input = input
    _isFocused = isFocused
    self.onAdd = onAdd
    self.onOpenDetail = onOpenDetail
    self.onOpenSequence = onOpenSequence
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

          Button(action: onOpenSequence) {
            HStack(spacing: 6) {
              Image(systemName: "list.bullet.rectangle.portrait")
                .font(.caption.weight(.semibold))
              Text("序列")
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
    .frame(minHeight: QuickAddDockLayout.minHeight)
    .background(
      RoundedRectangle(cornerRadius: cornerRadius + 6, style: .continuous)
        .fill(
          LinearGradient(
            stops: [
              .init(color: NornTheme.cardSurface.opacity(0.28), location: 0),
              .init(color: NornTheme.canvasBottom.opacity(0.10), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .padding(.horizontal, -4)
        .padding(.vertical, -4)
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
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius + 6, style: .continuous)
        .strokeBorder(NornTheme.borderStrong.opacity(0.35), lineWidth: 1)
        .padding(.horizontal, -4)
        .padding(.vertical, -4)
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
    QuickAddDock(input: $input, isFocused: $focused, onAdd: {}, onOpenDetail: {}, onOpenSequence: {})
  }
}

#Preview {
  QuickAddDockPreview()
}
