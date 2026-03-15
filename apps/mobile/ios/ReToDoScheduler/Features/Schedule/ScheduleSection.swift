import SwiftUI

struct ScheduleSection: View {
  @Binding var horizon: HorizonOption
  let scheduleView: ScheduleView
  let groupedBlocks: [ScheduleDayGroup]
  let titleForBlock: (ScheduleBlock) -> String

  var body: some View {
    Section("调度视图") {
      Picker("观察窗口", selection: $horizon) {
        ForEach(HorizonOption.allCases) { option in
          Text(option.label).tag(option)
        }
      }
      .pickerStyle(.segmented)

      if !scheduleView.warnings.isEmpty {
        ForEach(scheduleView.warnings) { warning in
          VStack(alignment: .leading, spacing: 4) {
            Text(warning.severity == "danger" ? "高风险" : "提示")
              .font(.caption.weight(.semibold))
              .foregroundStyle(warning.severity == "danger" ? Color.red : Color.orange)
            Text(warning.message)
              .font(.footnote)
          }
          .padding(.vertical, 4)
        }
      }

      if groupedBlocks.isEmpty {
        Text("当前窗口内还没有排入任何时间块。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(groupedBlocks) { group in
          VStack(alignment: .leading, spacing: 8) {
            Text(group.blocks.first.map { AppFormatters.formatDay($0.startAt) } ?? group.dayKey)
              .font(.headline)

            ForEach(group.blocks) { block in
              VStack(alignment: .leading, spacing: 4) {
                Text(titleForBlock(block))
                  .font(.subheadline.weight(.semibold))
                Text("\(AppFormatters.formatClock(block.startAt)) - \(AppFormatters.formatClock(block.endAt))")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 4)
            }
          }
          .padding(.vertical, 4)
        }
      }

      if !scheduleView.unscheduledSteps.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("未排入")
            .font(.headline)

          ForEach(scheduleView.unscheduledSteps) { step in
            VStack(alignment: .leading, spacing: 4) {
              Text("\(step.taskTitle) / \(step.title)")
                .font(.subheadline)
              Text("剩余 \(step.remainingMinutes)m | 损失 \(step.penaltyMissed)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
          }
        }
        .padding(.vertical, 4)
      }
    }
  }
}
