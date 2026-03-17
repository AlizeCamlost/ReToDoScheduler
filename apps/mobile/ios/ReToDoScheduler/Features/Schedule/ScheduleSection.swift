import SwiftUI

struct ScheduleSection: View {
  @Binding var calendarMode: CalendarDisplayMode
  let scheduleView: ScheduleView
  let titleForBlock: (ScheduleBlock) -> String
  let taskForBlock: (ScheduleBlock) -> Task?
  let taskForID: (String) -> Task?
  let onSelectTask: (Task) -> Void

  private var referenceDate: Date {
    scheduleView.horizonStart
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 10) {
          Text("时间格")
            .font(.system(size: 32, weight: .bold, design: .rounded))
          Text("同一批任务被投影到日、周、月三种时间视角中。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Picker("日历视图", selection: $calendarMode) {
          ForEach(CalendarDisplayMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        if !scheduleView.warnings.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(scheduleView.warnings) { warning in
                WarningChip(warning: warning)
              }
            }
          }
        }

        Group {
          switch calendarMode {
          case .day:
            DayScheduleView(
              date: referenceDate,
              blocks: scheduleView.blocks.filter { Calendar.current.isDate($0.startAt, inSameDayAs: referenceDate) },
              titleForBlock: titleForBlock,
              taskForBlock: taskForBlock,
              onSelectTask: onSelectTask
            )
          case .week:
            WeekScheduleView(
              weekStart: Calendar.current.startOfWeek(for: referenceDate),
              blocks: scheduleView.blocks,
              titleForBlock: titleForBlock,
              taskForBlock: taskForBlock,
              onSelectTask: onSelectTask
            )
          case .month:
            MonthScheduleView(
              monthDate: referenceDate,
              blocks: scheduleView.blocks,
              titleForBlock: titleForBlock,
              taskForBlock: taskForBlock,
              onSelectTask: onSelectTask
            )
          }
        }

        if !scheduleView.unscheduledSteps.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("尚未落入时间格")
              .font(.headline.weight(.semibold))

            ForEach(scheduleView.unscheduledSteps) { step in
              Button {
                if let task = taskForID(step.taskId) {
                  onSelectTask(task)
                }
              } label: {
                HStack(alignment: .top, spacing: 12) {
                  Circle()
                    .fill(Color.orange.opacity(0.85))
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                  VStack(alignment: .leading, spacing: 6) {
                    Text("\(step.taskTitle) / \(step.title)")
                      .font(.subheadline.weight(.semibold))
                      .foregroundStyle(.primary)
                    Text("剩余 \(step.remainingMinutes) 分钟")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }

                  Spacer()

                  Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(
                  RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.48))
                )
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 48)
    }
  }
}

private struct WarningChip: View {
  let warning: ScheduleWarning

  private var tint: Color {
    warning.severity == "danger" ? Color.red : Color.orange
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(warning.severity == "danger" ? "高风险" : "提示")
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
      Text(warning.message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(width: 220, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.white.opacity(0.52))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(tint.opacity(0.2), lineWidth: 1)
    )
  }
}

private struct DayScheduleView: View {
  let date: Date
  let blocks: [ScheduleBlock]
  let titleForBlock: (ScheduleBlock) -> String
  let taskForBlock: (ScheduleBlock) -> Task?
  let onSelectTask: (Task) -> Void

  private var hours: [Int] {
    hourAxis(for: blocks)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(AppFormatters.formatDay(date))
        .font(.headline.weight(.semibold))

      if blocks.isEmpty {
        EmptyCalendarCard(title: "今天还没有排入时间块", subtitle: "先在任务流里记录任务，或切到周/月视图看更长窗口。")
      } else {
        TimelineLayout(
          date: date,
          daySpan: 1,
          blocks: blocks,
          hours: hours,
          titleForBlock: titleForBlock,
          taskForBlock: taskForBlock,
          onSelectTask: onSelectTask
        )
        .frame(height: CGFloat(max(hours.count, 1)) * 68 + 32)
      }
    }
  }
}

private struct WeekScheduleView: View {
  let weekStart: Date
  let blocks: [ScheduleBlock]
  let titleForBlock: (ScheduleBlock) -> String
  let taskForBlock: (ScheduleBlock) -> Task?
  let onSelectTask: (Task) -> Void

  private var visibleBlocks: [ScheduleBlock] {
    let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    return blocks.filter { $0.startAt >= weekStart && $0.startAt < weekEnd }
  }

  private var hours: [Int] {
    hourAxis(for: visibleBlocks)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(weekTitle)
        .font(.headline.weight(.semibold))

      if visibleBlocks.isEmpty {
        EmptyCalendarCard(title: "本周暂时没有可视排期", subtitle: "当前窗口内的排期为空，或任务还未落入具体时间槽。")
      } else {
        TimelineLayout(
          date: weekStart,
          daySpan: 7,
          blocks: visibleBlocks,
          hours: hours,
          titleForBlock: titleForBlock,
          taskForBlock: taskForBlock,
          onSelectTask: onSelectTask
        )
        .frame(height: CGFloat(max(hours.count, 1)) * 54 + 42)
      }
    }
  }

  private var weekTitle: String {
    let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    return "\(AppFormatters.formatDay(weekStart)) - \(AppFormatters.formatDay(end))"
  }
}

private struct TimelineLayout: View {
  let date: Date
  let daySpan: Int
  let blocks: [ScheduleBlock]
  let hours: [Int]
  let titleForBlock: (ScheduleBlock) -> String
  let taskForBlock: (ScheduleBlock) -> Task?
  let onSelectTask: (Task) -> Void

  private var rowHeight: CGFloat {
    daySpan == 1 ? 68 : 54
  }

  private var dayLabels: [Date] {
    (0..<daySpan).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: date)) }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .trailing, spacing: 0) {
        Color.clear
          .frame(height: 26)

        ForEach(hours, id: \.self) { hour in
          Text(String(format: "%02d:00", hour))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(height: rowHeight, alignment: .topTrailing)
        }
      }
      .frame(width: 42)

      GeometryReader { geometry in
        let columnWidth = geometry.size.width / CGFloat(max(daySpan, 1))
        let totalHeight = CGFloat(hours.count) * rowHeight

        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.48))

          ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, day in
            Text(daySpan == 1 ? "今日" : shortDayLabel(for: day))
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .frame(width: columnWidth, alignment: .leading)
              .offset(x: CGFloat(index) * columnWidth + 12, y: 8)
          }

          Path { path in
            for row in 0...hours.count {
              let y = 26 + CGFloat(row) * rowHeight
              path.move(to: CGPoint(x: 0, y: y))
              path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }

            for column in 1..<daySpan {
              let x = CGFloat(column) * columnWidth
              path.move(to: CGPoint(x: x, y: 0))
              path.addLine(to: CGPoint(x: x, y: totalHeight + 26))
            }
          }
          .stroke(Color.primary.opacity(0.08), lineWidth: 1)

          ForEach(blocks) { block in
            if let task = taskForBlock(block) {
              Button {
                onSelectTask(task)
              } label: {
                TimelineBlockLabel(
                  title: titleForBlock(block),
                  timeText: "\(AppFormatters.formatClock(block.startAt)) - \(AppFormatters.formatClock(block.endAt))",
                  compact: daySpan > 1
                )
              }
              .buttonStyle(.plain)
              .frame(width: columnWidth - 10, height: blockHeight(block), alignment: .topLeading)
              .background(
                RoundedRectangle(cornerRadius: daySpan == 1 ? 18 : 14, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [Color(red: 0.22, green: 0.46, blue: 0.86), Color(red: 0.47, green: 0.65, blue: 0.95)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
              )
              .overlay(
                RoundedRectangle(cornerRadius: daySpan == 1 ? 18 : 14, style: .continuous)
                  .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
              )
              .offset(x: blockX(block, columnWidth: columnWidth) + 5, y: blockY(block) + 30)
            }
          }
        }
      }
    }
  }

  private func blockX(_ block: ScheduleBlock, columnWidth: CGFloat) -> CGFloat {
    let dayIndex = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: block.startAt)).day ?? 0
    return CGFloat(max(0, min(daySpan - 1, dayIndex))) * columnWidth
  }

  private func blockY(_ block: ScheduleBlock) -> CGFloat {
    guard let firstHour = hours.first else { return 0 }
    let dayStart = Calendar.current.startOfDay(for: block.startAt)
    let axisStart = Calendar.current.date(bySettingHour: firstHour, minute: 0, second: 0, of: dayStart) ?? dayStart
    let minutesOffset = max(0, Calendar.current.dateComponents([.minute], from: axisStart, to: block.startAt).minute ?? 0)
    return CGFloat(minutesOffset) / 60 * rowHeight
  }

  private func blockHeight(_ block: ScheduleBlock) -> CGFloat {
    let minutes = max(30, Calendar.current.dateComponents([.minute], from: block.startAt, to: block.endAt).minute ?? 30)
    return max(daySpan == 1 ? 52 : 36, CGFloat(minutes) / 60 * rowHeight - 4)
  }

  private func shortDayLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "E\nd"
    return formatter.string(from: date)
  }
}

private struct TimelineBlockLabel: View {
  let title: String
  let timeText: String
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 4 : 6) {
      Text(title)
        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(compact ? 2 : 3)
      Text(timeText)
        .font(compact ? .caption2 : .caption)
        .foregroundStyle(Color.white.opacity(0.82))
        .lineLimit(1)
    }
    .padding(.horizontal, compact ? 10 : 12)
    .padding(.vertical, compact ? 8 : 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct MonthScheduleView: View {
  let monthDate: Date
  let blocks: [ScheduleBlock]
  let titleForBlock: (ScheduleBlock) -> String
  let taskForBlock: (ScheduleBlock) -> Task?
  let onSelectTask: (Task) -> Void

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

  private var days: [Date] {
    Calendar.current.monthGrid(for: monthDate)
  }

  private var visibleMonth: DateInterval? {
    Calendar.current.dateInterval(of: .month, for: monthDate)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(monthTitle)
        .font(.headline.weight(.semibold))

      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { symbol in
          Text(symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }

        ForEach(days, id: \.self) { day in
          let dayBlocks = blocksForDay(day)
          MonthCell(
            date: day,
            inMonth: visibleMonth?.contains(day) ?? true,
            blocks: dayBlocks,
            titleForBlock: titleForBlock,
            taskForBlock: taskForBlock,
            onSelectTask: onSelectTask
          )
        }
      }
    }
  }

  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy 年 M 月"
    return formatter.string(from: monthDate)
  }

  private func blocksForDay(_ day: Date) -> [ScheduleBlock] {
    blocks.filter { Calendar.current.isDate($0.startAt, inSameDayAs: day) }.sorted { $0.startAt < $1.startAt }
  }
}

private struct MonthCell: View {
  let date: Date
  let inMonth: Bool
  let blocks: [ScheduleBlock]
  let titleForBlock: (ScheduleBlock) -> String
  let taskForBlock: (ScheduleBlock) -> Task?
  let onSelectTask: (Task) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(dayLabel)
        .font(.caption.weight(.semibold))
        .foregroundStyle(inMonth ? .primary : .secondary)

      if blocks.isEmpty {
        Spacer(minLength: 0)
      } else {
        ForEach(blocks.prefix(2)) { block in
          if let task = taskForBlock(block) {
            Button {
              onSelectTask(task)
            } label: {
              Text(titleForBlock(block))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.22, green: 0.46, blue: 0.86), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }

        if blocks.count > 2 {
          Text("+\(blocks.count - 2) 项")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(inMonth ? Color.white.opacity(0.56) : Color.white.opacity(0.22))
    )
  }

  private var dayLabel: String {
    String(Calendar.current.component(.day, from: date))
  }
}

private struct EmptyCalendarCard: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline.weight(.semibold))
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color.white.opacity(0.44))
    )
  }
}

private func hourAxis(for blocks: [ScheduleBlock]) -> [Int] {
  let defaultRange = Array(8...20)
  guard !blocks.isEmpty else { return defaultRange }

  let hours = blocks.flatMap { block in
    [
      Calendar.current.component(.hour, from: block.startAt),
      Calendar.current.component(.hour, from: block.endAt)
    ]
  }

  let minHour = max(0, min((hours.min() ?? 8) - 1, 8))
  let maxHour = min(23, max((hours.max() ?? 20) + 1, 20))
  return Array(minHour...maxHour)
}

private extension Calendar {
  func startOfWeek(for date: Date) -> Date {
    dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
  }

  func monthGrid(for date: Date) -> [Date] {
    guard
      let monthInterval = dateInterval(of: .month, for: date),
      let startWeek = dateInterval(of: .weekOfYear, for: monthInterval.start)?.start,
      let endWeekStart = dateInterval(of: .weekOfYear, for: monthInterval.end.addingTimeInterval(-1))?.start,
      let gridEnd = self.date(byAdding: .day, value: 7, to: endWeekStart)
    else {
      return []
    }

    var days: [Date] = []
    var cursor = startWeek
    while cursor < gridEnd {
      days.append(cursor)
      cursor = self.date(byAdding: .day, value: 1, to: cursor) ?? gridEnd
    }
    return days
  }
}
