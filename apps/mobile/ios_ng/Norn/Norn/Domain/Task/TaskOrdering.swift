import Foundation

enum TaskOrdering {
  private static let nornKey = "norn"
  private static let sequenceRankKey = "sequenceRank"

  static func sorted(_ tasks: [Task]) -> [Task] {
    tasks.sorted(by: compare(_:_:))
  }

  static func sequenceRank(for task: Task) -> Int? {
    guard task.status.isSequenced else {
      return nil
    }
    return sequenceRank(in: task.extJSON)
  }

  static func sequenceRank(in extJSON: [String: JSONValue]) -> Int? {
    let norn = extJSON[nornKey]?.objectValue
    return norn?[sequenceRankKey]?.intValue
  }

  static func applyingSequenceRank(_ rank: Int?, to task: Task) -> Task {
    var updatedTask = task
    updatedTask.extJSON = applyingSequenceRank(rank, to: task.extJSON)
    return updatedTask
  }

  private static func applyingSequenceRank(_ rank: Int?, to extJSON: [String: JSONValue]) -> [String: JSONValue] {
    var updatedExtJSON = extJSON
    var norn = updatedExtJSON[nornKey]?.objectValue ?? [:]

    if let rank {
      norn[sequenceRankKey] = .number(Double(rank))
    } else {
      norn.removeValue(forKey: sequenceRankKey)
    }

    if norn.isEmpty {
      updatedExtJSON.removeValue(forKey: nornKey)
    } else {
      updatedExtJSON[nornKey] = .object(norn)
    }

    return updatedExtJSON
  }

  private static func compare(_ left: Task, _ right: Task) -> Bool {
    let leftSequenceRank = sequenceRank(for: left)
    let rightSequenceRank = sequenceRank(for: right)

    if leftSequenceRank != nil || rightSequenceRank != nil {
      switch (leftSequenceRank, rightSequenceRank) {
      case let (lhs?, rhs?) where lhs != rhs:
        return lhs < rhs
      case (_?, nil):
        return true
      case (nil, _?):
        return false
      default:
        break
      }
    }

    let leftKairosRank = kairosRank(in: left.extJSON)
    let rightKairosRank = kairosRank(in: right.extJSON)

    if leftKairosRank != nil || rightKairosRank != nil {
      switch (leftKairosRank, rightKairosRank) {
      case let (lhs?, rhs?) where lhs != rhs:
        return lhs < rhs
      case (_?, nil):
        return true
      case (nil, _?):
        return false
      default:
        break
      }
    }

    let leftBundle = TaskBundleMetadata.metadata(for: left)
    let rightBundle = TaskBundleMetadata.metadata(for: right)

    if
      let leftBundle,
      let rightBundle,
      leftBundle.id == rightBundle.id,
      leftBundle.position != rightBundle.position
    {
      return leftBundle.position < rightBundle.position
    }

    return left.updatedAt > right.updatedAt
  }

  private static func kairosRank(in extJSON: [String: JSONValue]) -> Int? {
    if let kairos = extJSON["kairos"]?.objectValue, let rank = kairos["rank"]?.intValue {
      return rank
    }
    return extJSON["rank"]?.intValue
  }
}

private extension TaskStatus {
  var isSequenced: Bool {
    switch self {
    case .todo, .doing:
      return true
    case .done, .archived:
      return false
    }
  }
}
