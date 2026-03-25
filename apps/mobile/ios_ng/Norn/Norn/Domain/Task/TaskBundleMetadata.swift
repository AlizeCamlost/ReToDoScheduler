import Foundation

struct TaskBundleMetadata: Hashable {
  enum Kind: String, Hashable {
    case taskSequence
  }

  let id: String
  let title: String?
  let position: Int
  let count: Int
  let kind: Kind

  init(
    id: String,
    title: String?,
    position: Int,
    count: Int,
    kind: Kind = .taskSequence
  ) {
    self.id = id
    self.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    self.position = position
    self.count = count
    self.kind = kind
  }
}

extension TaskBundleMetadata {
  private static let nornKey = "norn"
  private static let bundleKey = "taskBundle"
  private static let idKey = "id"
  private static let titleKey = "title"
  private static let positionKey = "position"
  private static let countKey = "count"
  private static let kindKey = "kind"

  static func metadata(for task: Task) -> TaskBundleMetadata? {
    metadata(in: task.extJSON)
  }

  static func metadata(in extJSON: [String: JSONValue]) -> TaskBundleMetadata? {
    guard
      let norn = extJSON[nornKey]?.objectValue,
      let bundle = norn[bundleKey]?.objectValue,
      let id = bundle[idKey]?.stringValue,
      let position = bundle[positionKey]?.intValue,
      let count = bundle[countKey]?.intValue,
      let kindRawValue = bundle[kindKey]?.stringValue,
      let kind = Kind(rawValue: kindRawValue)
    else {
      return nil
    }

    return TaskBundleMetadata(
      id: id,
      title: bundle[titleKey]?.stringValue,
      position: position,
      count: count,
      kind: kind
    )
  }

  func applying(to extJSON: [String: JSONValue]) -> [String: JSONValue] {
    var updatedExtJSON = extJSON
    var norn = updatedExtJSON[Self.nornKey]?.objectValue ?? [:]
    var bundleObject: [String: JSONValue] = [
      Self.idKey: .string(id),
      Self.positionKey: .number(Double(position)),
      Self.countKey: .number(Double(count)),
      Self.kindKey: .string(kind.rawValue)
    ]

    if let title {
      bundleObject[Self.titleKey] = .string(title)
    }

    norn[Self.bundleKey] = .object(bundleObject)
    updatedExtJSON[Self.nornKey] = .object(norn)
    return updatedExtJSON
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
