import SwiftUI

struct SettingsSheet: View {
  @FocusState private var isInputFocused: Bool

  @Binding var apiBaseURL: String
  @Binding var apiAuthToken: String
  @Binding var timeTemplate: TimeTemplate
  let onClose: () -> Void
  let onSave: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("同步设置") {
          TextField("API Base URL", text: $apiBaseURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .focused($isInputFocused)

          SecureField("API Auth Token", text: $apiAuthToken)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isInputFocused)
        }

        TimeTemplateEditorSection(timeTemplate: $timeTemplate, keyboardFocus: $isInputFocused)

        Section {
          Text("留空也可以先离线使用，任务会保存在本机。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .simultaneousGesture(
        TapGesture().onEnded {
          isInputFocused = false
        }
      )
      .navigationTitle("设置")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") {
            isInputFocused = false
            onClose()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            isInputFocused = false
            onSave()
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()

          Button("完成") {
            isInputFocused = false
          }
        }
      }
    }
  }
}
