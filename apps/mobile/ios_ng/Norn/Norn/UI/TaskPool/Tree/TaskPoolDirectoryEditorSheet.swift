import SwiftUI

struct TaskPoolDirectoryEditorSheet: View {
  let title: String
  let message: String
  let initialName: String
  let submitLabel: String
  let onSubmit: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String

  init(
    title: String,
    message: String,
    initialName: String = "",
    submitLabel: String = "保存",
    onSubmit: @escaping (String) -> Void
  ) {
    self.title = title
    self.message = message
    self.initialName = initialName
    self.submitLabel = submitLabel
    self.onSubmit = onSubmit
    _name = State(initialValue: initialName)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        NornScreenBackground()

        VStack(alignment: .leading, spacing: 14) {
          if !message.isEmpty {
            Text(message)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          TextField("目录名称", text: $name)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NornTheme.cardSurface)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
            )

          Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 16)
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("取消") {
            dismiss()
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button(submitLabel) {
            onSubmit(name)
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .presentationDetents([.fraction(0.28)])
    .presentationDragIndicator(.visible)
  }
}
