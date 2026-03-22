import Foundation

struct QuickAddDraft: Hashable {
  var rawInput: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var tags: [String]

  init(
    rawInput: String,
    title: String,
    estimatedMinutes: Int = 30,
    minChunkMinutes: Int = 25,
    dueAt: Date? = nil,
    tags: [String] = []
  ) {
    self.rawInput = rawInput
    self.title = title
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dueAt = dueAt
    self.tags = tags
  }
}
