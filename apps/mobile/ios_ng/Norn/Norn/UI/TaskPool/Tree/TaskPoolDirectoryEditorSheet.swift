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

        VStack(alignment: .leading, spacing: 18) {
          Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          TextField("目录名称", text: $name)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NornTheme.cardSurface)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
            )

          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
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
