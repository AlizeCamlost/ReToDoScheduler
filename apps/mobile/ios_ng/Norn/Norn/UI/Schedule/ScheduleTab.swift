import SwiftUI

enum CalendarMode: String, CaseIterable, Identifiable {
  case day, week, month
  var id: String { rawValue }
  var label: String {
    switch self {
    case .day:   return "日"
    case .week:  return "周"
    case .month: return "月"
    }
  }
}

struct ScheduleTab: View {
  @State private var mode: CalendarMode = .week

  var body: some View {
    VStack(spacing: 0) {
      header
      EdgeFadeDivider()
      placeholder
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("时间视图")
        .font(.title2.weight(.bold))

      Picker("", selection: $mode) {
        ForEach(CalendarMode.allCases) { m in
          Text(m.label).tag(m)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 16)
  }

  private var placeholder: some View {
    ScrollView {
      VStack {
        Spacer(minLength: 120)
        Text("日历视图开发中")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
        Spacer(minLength: 120)
      }
      .frame(maxWidth: .infinity)
    }
  }
}

#Preview {
  ScheduleTab()
}
