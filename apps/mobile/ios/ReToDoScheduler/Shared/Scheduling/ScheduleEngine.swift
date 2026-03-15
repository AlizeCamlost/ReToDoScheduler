import Foundation

private struct SchedulerStep: Equatable {
  var id: String
  var taskId: String
  var taskTitle: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var rewardOnTime: Int
  var penaltyMissed: Int
  var dependsOnStepIds: [String]
  var concurrencyMode: ConcurrencyMode
  var source: String
  var updatedAt: Date
  var importance: Int
  var legacyValue: Int
}

private struct SchedulerLink {
  var fromStepId: String
  var toStepId: String
}

private struct SchedulerGraph {
  var steps: [SchedulerStep]
  var links: [SchedulerLink]
}

struct ScheduleEngine {
  static func refreshSchedule(
    tasks: [Task],
    template: TimeTemplate = .default,
    now: Date = Date(),
    horizonDays: Int
  ) -> ScheduleView {
    let horizonEnd = Calendar.current.date(byAdding: .day, value: horizonDays, to: now) ?? now
    let steps = buildTaskSteps(from: tasks)
    let graph = buildGraph(tasks: tasks, steps: steps)
    let slots = buildTimeSlots(template: template, horizonStart: now, horizonEnd: horizonEnd)

    if detectCycle(graph) {
      let ordered = steps.map {
        OrderedTaskStep(
          stepId: $0.id,
          taskId: $0.taskId,
          taskTitle: $0.taskTitle,
          title: $0.title,
          dueAt: $0.dueAt,
          plannedMinutes: 0,
          remainingMinutes: $0.estimatedMinutes,
          rewardOnTime: $0.rewardOnTime,
          penaltyMissed: $0.penaltyMissed,
          source: $0.source,
          dependsOnStepIds: $0.dependsOnStepIds
        )
      }

      return ScheduleView(
        horizonStart: now,
        horizonEnd: horizonEnd,
        slots: slots,
        blocks: [],
        orderedSteps: ordered,
        unscheduledSteps: ordered,
        warnings: [
          ScheduleWarning(
            code: "dependency-cycle",
            severity: "danger",
            message: "检测到循环依赖，当前无法生成调度视图。",
            taskId: nil,
            stepId: nil
          )
        ]
      )
    }

    var remaining = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0.estimatedMinutes) })
    var blocks: [ScheduleBlock] = []
    var warnings: [ScheduleWarning] = []
    var unfinished = Set(steps.map(\.id))

    while !unfinished.isEmpty {
      let readySteps = steps
        .filter { unfinished.contains($0.id) }
        .filter { dependencyReadyAt(for: $0, horizonStart: now, remaining: remaining, blocks: blocks) != nil }
        .sorted(by: compareSteps)

      if readySteps.isEmpty {
        break
      }

      var placedAny = false

      for step in readySteps {
        let candidates = slots.enumerated().compactMap { index, slot -> (PlannedTimeSlot, Int, Int)? in
          guard let freeMinutes = canPlaceChunk(
            step: step,
            slot: slot,
            slotIndex: index,
            horizonStart: now,
            slots: slots,
            remaining: remaining,
            blocks: blocks
          ) else {
            return nil
          }
          return (slot, index, freeMinutes)
        }
        .sorted { left, right in
          scoreCandidate(step: step, slot: left.0) > scoreCandidate(step: step, slot: right.0)
        }

        guard let best = candidates.first else {
          continue
        }

        let remainingMinutes = remaining[step.id] ?? 0
        guard let chunkMinutes = chooseChunkMinutes(
          remainingMinutes: remainingMinutes,
          freeMinutes: best.2,
          minChunkMinutes: step.minChunkMinutes
        ) else {
          continue
        }

        let block = buildBlock(step: step, slot: best.0, chunkMinutes: chunkMinutes, existing: blocks)
        blocks.append(block)
        remaining[step.id] = remainingMinutes - chunkMinutes
        if remaining[step.id] == 0 {
          unfinished.remove(step.id)
        }

        placedAny = true
        break
      }

      if !placedAny {
        break
      }
    }

    for stepId in unfinished {
      guard let step = steps.first(where: { $0.id == stepId }) else { continue }
      warnings.append(
        ScheduleWarning(
          code: "unscheduled",
          severity: step.dueAt == nil ? "warning" : "danger",
          message: step.dueAt == nil
            ? "\(step.taskTitle) / \(step.title) 在当前时间窗口内未排入。"
            : "\(step.taskTitle) / \(step.title) 在当前时间窗口内无法于截止前排入。",
          taskId: step.taskId,
          stepId: step.id
        )
      )
    }

    if !warnings.isEmpty && blocks.isEmpty && !steps.isEmpty {
      warnings.insert(
        ScheduleWarning(
          code: "capacity",
          severity: "warning",
          message: "当前观察窗口容量不足，调度器只生成了部分或空视图。",
          taskId: nil,
          stepId: nil
        ),
        at: 0
      )
    }

    let ordered = steps.map { step in
      let plannedMinutes = blocks
        .filter { $0.stepId == step.id }
        .reduce(0) { $0 + minutesBetween($1.startAt, $1.endAt) }

      return OrderedTaskStep(
        stepId: step.id,
        taskId: step.taskId,
        taskTitle: step.taskTitle,
        title: step.title,
        dueAt: step.dueAt,
        plannedMinutes: plannedMinutes,
        remainingMinutes: remaining[step.id] ?? step.estimatedMinutes,
        rewardOnTime: step.rewardOnTime,
        penaltyMissed: step.penaltyMissed,
        source: step.source,
        dependsOnStepIds: step.dependsOnStepIds
      )
    }

    let scheduled = ordered
      .filter { $0.plannedMinutes > 0 }
      .sorted { left, right in
        let firstA = blocks.first(where: { $0.stepId == left.stepId })?.startAt ?? left.dueAt ?? horizonEnd
        let firstB = blocks.first(where: { $0.stepId == right.stepId })?.startAt ?? right.dueAt ?? horizonEnd
        return firstA < firstB
      }
    let unscheduled = ordered
      .filter { $0.remainingMinutes > 0 }
      .sorted(by: compareUnscheduled)

    return ScheduleView(
      horizonStart: now,
      horizonEnd: horizonEnd,
      slots: slots,
      blocks: blocks.sorted { $0.startAt < $1.startAt },
      orderedSteps: scheduled + unscheduled,
      unscheduledSteps: unscheduled,
      warnings: warnings
    )
  }

  static func groupBlocksByDay(_ blocks: [ScheduleBlock]) -> [ScheduleDayGroup] {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.dateFormat = "yyyy-MM-dd"

    let grouped = Dictionary(grouping: blocks) { formatter.string(from: $0.startAt) }
    return grouped.keys.sorted().map { key in
      ScheduleDayGroup(dayKey: key, blocks: grouped[key, default: []].sorted { $0.startAt < $1.startAt })
    }
  }

  private static func buildTaskSteps(from tasks: [Task]) -> [SchedulerStep] {
    var result: [SchedulerStep] = []

    for task in tasks where task.status != .done && task.status != .archived {
      if task.steps.isEmpty {
        result.append(
          SchedulerStep(
            id: "task:\(task.id)",
            taskId: task.id,
            taskTitle: task.title,
            title: task.title,
            estimatedMinutes: task.estimatedMinutes,
            minChunkMinutes: task.minChunkMinutes,
            dueAt: task.dueAt,
            rewardOnTime: task.scheduleValue.rewardOnTime,
            penaltyMissed: task.scheduleValue.penaltyMissed,
            dependsOnStepIds: [],
            concurrencyMode: task.concurrencyMode,
            source: "task",
            updatedAt: task.updatedAt,
            importance: task.importance,
            legacyValue: task.value
          )
        )
        continue
      }

      var localToReal: [String: String] = [:]
      for step in task.steps {
        localToReal[step.id] = "task:\(task.id)/step:\(step.id)"
      }

      for step in task.steps {
        result.append(
          SchedulerStep(
            id: localToReal[step.id] ?? "task:\(task.id)/step:\(step.id)",
            taskId: task.id,
            taskTitle: task.title,
            title: step.title,
            estimatedMinutes: step.estimatedMinutes,
            minChunkMinutes: step.minChunkMinutes,
            dueAt: task.dueAt,
            rewardOnTime: task.scheduleValue.rewardOnTime,
            penaltyMissed: task.scheduleValue.penaltyMissed,
            dependsOnStepIds: step.dependsOnStepIds.compactMap { localToReal[$0] },
            concurrencyMode: task.concurrencyMode,
            source: "task-step",
            updatedAt: task.updatedAt,
            importance: task.importance,
            legacyValue: task.value
          )
        )
      }
    }

    return result
  }

  private static func buildGraph(tasks: [Task], steps: [SchedulerStep]) -> SchedulerGraph {
    var links: [SchedulerLink] = []
    var stepsByTask: [String: [SchedulerStep]] = [:]

    for step in steps {
      stepsByTask[step.taskId, default: []].append(step)
      for dependency in step.dependsOnStepIds {
        links.append(SchedulerLink(fromStepId: dependency, toStepId: step.id))
      }
    }

    var headsByTask: [String: [String]] = [:]
    var tailsByTask: [String: [String]] = [:]

    for task in tasks {
      let taskSteps = stepsByTask[task.id, default: []]
      guard !taskSteps.isEmpty else { continue }

      var inbound: [String: Int] = Dictionary(uniqueKeysWithValues: taskSteps.map { ($0.id, 0) })
      var outbound: [String: Int] = Dictionary(uniqueKeysWithValues: taskSteps.map { ($0.id, 0) })

      for link in links where taskSteps.contains(where: { $0.id == link.fromStepId }) && taskSteps.contains(where: { $0.id == link.toStepId }) {
        inbound[link.toStepId, default: 0] += 1
        outbound[link.fromStepId, default: 0] += 1
      }

      headsByTask[task.id] = taskSteps.filter { inbound[$0.id, default: 0] == 0 }.map(\.id)
      tailsByTask[task.id] = taskSteps.filter { outbound[$0.id, default: 0] == 0 }.map(\.id)
    }

    for task in tasks {
      let heads = headsByTask[task.id, default: []]
      guard !heads.isEmpty else { continue }

      for dependencyTaskID in task.dependsOnTaskIds {
        for tail in tailsByTask[dependencyTaskID, default: []] {
          for head in heads {
            links.append(SchedulerLink(fromStepId: tail, toStepId: head))
          }
        }
      }
    }

    return SchedulerGraph(steps: steps, links: links)
  }

  private static func buildTimeSlots(template: TimeTemplate, horizonStart: Date, horizonEnd: Date) -> [PlannedTimeSlot] {
    let calendar = Calendar.current
    var cursor = calendar.startOfDay(for: horizonStart)
    var slots: [PlannedTimeSlot] = []

    while cursor <= horizonEnd {
      let weekday = convertWeekday(calendar.component(.weekday, from: cursor))
      let ranges = template.weeklyRanges.filter { $0.weekday == weekday && $0.startTime < $0.endTime }

      for range in ranges {
        let startParts = range.startTime.split(separator: ":").compactMap { Int($0) }
        let endParts = range.endTime.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2 else { continue }

        let startAt = calendar.date(
          bySettingHour: startParts[0],
          minute: startParts[1],
          second: 0,
          of: cursor
        ) ?? cursor
        let endAt = calendar.date(
          bySettingHour: endParts[0],
          minute: endParts[1],
          second: 0,
          of: cursor
        ) ?? cursor

        if endAt <= horizonStart || startAt >= horizonEnd {
          continue
        }

        slots.append(
          PlannedTimeSlot(
            id: "\(range.id)-\(DateCodec.encode(startAt))",
            startAt: startAt,
            endAt: endAt,
            durationMinutes: minutesBetween(startAt, endAt)
          )
        )
      }

      cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? horizonEnd.addingTimeInterval(1)
    }

    return slots.sorted { $0.startAt < $1.startAt }
  }

  private static func detectCycle(_ graph: SchedulerGraph) -> Bool {
    var inDegree = Dictionary(uniqueKeysWithValues: graph.steps.map { ($0.id, 0) })
    var outgoing = Dictionary(uniqueKeysWithValues: graph.steps.map { ($0.id, [String]()) })

    for link in graph.links {
      inDegree[link.toStepId, default: 0] += 1
      outgoing[link.fromStepId, default: []].append(link.toStepId)
    }

    var queue = inDegree.filter { $0.value == 0 }.map(\.key)
    var visited = 0

    while !queue.isEmpty {
      let current = queue.removeFirst()
      visited += 1

      for target in outgoing[current, default: []] {
        let next = (inDegree[target] ?? 0) - 1
        inDegree[target] = next
        if next == 0 {
          queue.append(target)
        }
      }
    }

    return visited != graph.steps.count
  }

  private static func compareSteps(_ left: SchedulerStep, _ right: SchedulerStep) -> Bool {
    if left.penaltyMissed != right.penaltyMissed { return left.penaltyMissed > right.penaltyMissed }
    let leftDue = left.dueAt ?? .distantFuture
    let rightDue = right.dueAt ?? .distantFuture
    if leftDue != rightDue { return leftDue < rightDue }
    if left.minChunkMinutes != right.minChunkMinutes { return left.minChunkMinutes > right.minChunkMinutes }
    if left.rewardOnTime != right.rewardOnTime { return left.rewardOnTime > right.rewardOnTime }
    if left.legacyValue != right.legacyValue { return left.legacyValue > right.legacyValue }
    if left.importance != right.importance { return left.importance > right.importance }
    return left.updatedAt < right.updatedAt
  }

  private static func scoreCandidate(step: SchedulerStep, slot: PlannedTimeSlot) -> Double {
    let dueSlack: Double
    if let dueAt = step.dueAt {
      dueSlack = max(0, dueAt.timeIntervalSince(slot.endAt) / 60)
    } else {
      dueSlack = 10_000
    }

    return Double(step.penaltyMissed * 10 + step.rewardOnTime * 2 + step.minChunkMinutes) - dueSlack * 0.01 - slot.startAt.timeIntervalSince1970 * 0.0000000001
  }

  private static func dependencyReadyAt(
    for step: SchedulerStep,
    horizonStart: Date,
    remaining: [String: Int],
    blocks: [ScheduleBlock]
  ) -> Date? {
    var readyAt = horizonStart

    for dependency in step.dependsOnStepIds {
      guard let completedAt = completedAt(for: dependency, remaining: remaining, blocks: blocks) else {
        return nil
      }
      if completedAt > readyAt {
        readyAt = completedAt
      }
    }

    if let ownLastEnd = lastBlockEnd(for: step.id, blocks: blocks), ownLastEnd > readyAt {
      readyAt = ownLastEnd
    }

    return readyAt
  }

  private static func completedAt(for stepID: String, remaining: [String: Int], blocks: [ScheduleBlock]) -> Date? {
    guard (remaining[stepID] ?? 0) == 0 else { return nil }
    return lastBlockEnd(for: stepID, blocks: blocks)
  }

  private static func lastBlockEnd(for stepID: String, blocks: [ScheduleBlock]) -> Date? {
    blocks.filter { $0.stepId == stepID }.map(\.endAt).max()
  }

  private static func canPlaceChunk(
    step: SchedulerStep,
    slot: PlannedTimeSlot,
    slotIndex: Int,
    horizonStart: Date,
    slots: [PlannedTimeSlot],
    remaining: [String: Int],
    blocks: [ScheduleBlock]
  ) -> Int? {
    let remainingMinutes = remaining[step.id] ?? 0
    guard remainingMinutes > 0 else { return nil }
    guard step.concurrencyMode == .serial else { return nil }
    guard let readyAt = dependencyReadyAt(for: step, horizonStart: horizonStart, remaining: remaining, blocks: blocks) else {
      return nil
    }

    let tailStart = slotTailStart(slot: slot, blocks: blocks)
    guard readyAt <= tailStart else { return nil }

    let freeMinutes = max(0, slot.durationMinutes - usedMinutes(slotID: slot.id, blocks: blocks))
    guard freeMinutes >= step.minChunkMinutes else { return nil }

    if !canStillFinishBeforeDue(step: step, fromSlotIndex: slotIndex, readyAt: readyAt, remainingMinutes: remainingMinutes, slots: slots, blocks: blocks) {
      return nil
    }

    return freeMinutes
  }

  private static func canStillFinishBeforeDue(
    step: SchedulerStep,
    fromSlotIndex: Int,
    readyAt: Date,
    remainingMinutes: Int,
    slots: [PlannedTimeSlot],
    blocks: [ScheduleBlock]
  ) -> Bool {
    guard let dueAt = step.dueAt else { return true }
    var capacity = 0

    for index in fromSlotIndex..<slots.count {
      let slot = slots[index]
      let tailStart = slotTailStart(slot: slot, blocks: blocks)
      let usableStart = max(tailStart, readyAt)
      if usableStart >= slot.endAt || usableStart >= dueAt {
        continue
      }

      let usableEnd = min(slot.endAt, dueAt)
      capacity += minutesBetween(usableStart, usableEnd)
      if capacity >= remainingMinutes {
        return true
      }
    }

    return false
  }

  private static func chooseChunkMinutes(remainingMinutes: Int, freeMinutes: Int, minChunkMinutes: Int) -> Int? {
    var chunkMinutes = min(remainingMinutes, freeMinutes)
    guard chunkMinutes >= minChunkMinutes else { return nil }

    let remainder = remainingMinutes - chunkMinutes
    if remainder == 0 || remainder >= minChunkMinutes {
      return chunkMinutes
    }

    chunkMinutes -= (minChunkMinutes - remainder)
    return chunkMinutes >= minChunkMinutes ? chunkMinutes : nil
  }

  private static func buildBlock(step: SchedulerStep, slot: PlannedTimeSlot, chunkMinutes: Int, existing: [ScheduleBlock]) -> ScheduleBlock {
    let tailStart = slotTailStart(slot: slot, blocks: existing)
    return ScheduleBlock(
      id: "\(step.id):\(slot.id):\(DateCodec.encode(tailStart))",
      taskId: step.taskId,
      stepId: step.id,
      slotId: slot.id,
      startAt: tailStart,
      endAt: tailStart.addingTimeInterval(Double(chunkMinutes * 60)),
      isParallel: false
    )
  }

  private static func compareUnscheduled(_ left: OrderedTaskStep, _ right: OrderedTaskStep) -> Bool {
    if left.penaltyMissed != right.penaltyMissed { return left.penaltyMissed > right.penaltyMissed }
    let leftDue = left.dueAt ?? .distantFuture
    let rightDue = right.dueAt ?? .distantFuture
    if leftDue != rightDue { return leftDue < rightDue }
    return left.title.localizedCompare(right.title) == .orderedAscending
  }

  private static func slotTailStart(slot: PlannedTimeSlot, blocks: [ScheduleBlock]) -> Date {
    slot.startAt.addingTimeInterval(Double(usedMinutes(slotID: slot.id, blocks: blocks) * 60))
  }

  private static func usedMinutes(slotID: String, blocks: [ScheduleBlock]) -> Int {
    blocks.filter { $0.slotId == slotID }.reduce(0) { $0 + minutesBetween($1.startAt, $1.endAt) }
  }

  private static func minutesBetween(_ start: Date, _ end: Date) -> Int {
    max(0, Int(round(end.timeIntervalSince(start) / 60)))
  }

  private static func convertWeekday(_ calendarWeekday: Int) -> Int {
    calendarWeekday == 1 ? 7 : calendarWeekday - 1
  }
}
