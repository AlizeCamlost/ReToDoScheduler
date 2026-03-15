import SwiftUI

private let weekdayLabels: [(value: Int, label: String)] = [
  (1, "周一"),
  (2, "周二"),
  (3, "周三"),
  (4, "周四"),
  (5, "周五"),
  (6, "周六"),
  (7, "周日")
]

struct TimeTemplateEditorSection: View {
  @Binding var timeTemplate: TimeTemplate

  var body: some View {
    Section {
      Button("添加时间段", action: addRange)
    } header: {
      Text("时间模板")
    } footer: {
      Text("时间模板是背景容量输入，不直接和调度策略耦合。")
    }

    ForEach(Array(timeTemplate.weeklyRanges.indices), id: \.self) { index in
      Section {
        Picker("星期", selection: binding(for: index, keyPath: \.weekday, fallback: 1)) {
          ForEach(weekdayLabels, id: \.value) { option in
            Text(option.label).tag(option.value)
          }
        }

        TextField(
          "开始时间",
          text: binding(for: index, keyPath: \.startTime, fallback: "09:00")
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

        TextField(
          "结束时间",
          text: binding(for: index, keyPath: \.endTime, fallback: "10:00")
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

        Button("删除时间段", role: .destructive) {
          timeTemplate.weeklyRanges.remove(at: index)
        }
      } header: {
        Text(timeTemplate.weeklyRanges[index].id)
      }
    }
  }

  private func addRange() {
    timeTemplate.weeklyRanges.append(
      WeeklyTimeRange(
        id: UUID().uuidString,
        weekday: 1,
        startTime: "09:00",
        endTime: "10:00"
      )
    )
  }

  private func binding<Value>(
    for index: Int,
    keyPath: WritableKeyPath<WeeklyTimeRange, Value>,
    fallback: Value
  ) -> Binding<Value> {
    Binding(
      get: {
        guard timeTemplate.weeklyRanges.indices.contains(index) else { return fallback }
        return timeTemplate.weeklyRanges[index][keyPath: keyPath]
      },
      set: { newValue in
        guard timeTemplate.weeklyRanges.indices.contains(index) else { return }
        timeTemplate.weeklyRanges[index][keyPath: keyPath] = newValue
      }
    )
  }
}
