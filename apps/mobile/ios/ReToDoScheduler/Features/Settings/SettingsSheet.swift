import SwiftUI

struct SettingsSheet: View {
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

          SecureField("API Auth Token", text: $apiAuthToken)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }

        TimeTemplateEditorSection(timeTemplate: $timeTemplate)

        Section {
          Text("留空也可以先离线使用，任务会保存在本机。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("设置")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭", action: onClose)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存", action: onSave)
        }
      }
    }
  }
}
