import SwiftUI

struct QuickAddSection: View {
  private let controlHeight: CGFloat = 60
  private let contentInset: CGFloat = 13

  @Binding var input: String
  var keyboardFocus: FocusState<AppInputFocusTarget?>.Binding
  let syncMessage: String
  let isSyncing: Bool
  let onAdd: () -> Void
  let onSync: () -> Void

  private var trimmedInput: String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSubmit: Bool {
    !trimmedInput.isEmpty
  }

  private var isFocused: Bool {
    keyboardFocus.wrappedValue == .quickAdd
  }

  var body: some View {
    HStack(alignment: .center, spacing: isFocused ? 12 : 0) {
      HStack(spacing: 12) {
        TextField("快速添加任务", text: $input)
          .focused(keyboardFocus, equals: .quickAdd)
          .submitLabel(.done)
          .textInputAutocapitalization(.sentences)
          .onSubmit(onAdd)

        if !isFocused, !syncMessage.isEmpty {
          Text(syncMessage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .transition(.opacity)
        }
      }
      .frame(minHeight: controlHeight)
      .frame(maxWidth: .infinity)

      if isFocused {
        HStack(spacing: 10) {
          QuickAddOrbButton(
            systemName: isSyncing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise",
            accessibilityLabel: isSyncing ? "同步中" : "立即同步",
            style: .secondary,
            action: onSync
          )
          .disabled(isSyncing)
          .opacity(isSyncing ? 0.72 : 1)

          QuickAddOrbButton(
            systemName: "arrow.up",
            accessibilityLabel: "添加任务",
            style: .primary,
            action: onAdd
          )
          .disabled(!canSubmit)
          .opacity(canSubmit ? 1 : 0.44)
        }
        .frame(height: controlHeight)
        .transition(
          .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.86, anchor: .leading)),
            removal: .move(edge: .trailing).combined(with: .opacity)
          )
        )
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, contentInset)
    .frame(minHeight: controlHeight)
    .animation(.spring(response: 0.30, dampingFraction: 0.82), value: isFocused)
    .animation(.spring(response: 0.24, dampingFraction: 0.88), value: canSubmit)
  }
}

private struct QuickAddOrbButton: View {
  enum Style: Equatable {
    case primary
    case secondary
  }

  let systemName: String
  let accessibilityLabel: String
  let style: Style
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(style == .primary ? Color.white : Color.primary.opacity(0.88))
        .frame(width: 60, height: 60)
        .background(
          Circle()
            .fill(backgroundFill)
        )
        .overlay(
          Circle()
            .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 16, y: 8)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }

  private var backgroundFill: AnyShapeStyle {
    if style == .primary {
      return AnyShapeStyle(
        LinearGradient(
          colors: [Color.black.opacity(0.94), Color.black.opacity(0.72)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    } else {
      return AnyShapeStyle(Color.white.opacity(0.84))
    }
  }

  private var borderColor: Color {
    style == .primary ? Color.white.opacity(0.18) : Color.white.opacity(0.82)
  }

  private var shadowColor: Color {
    style == .primary ? Color.black.opacity(0.18) : Color.black.opacity(0.10)
  }
}
