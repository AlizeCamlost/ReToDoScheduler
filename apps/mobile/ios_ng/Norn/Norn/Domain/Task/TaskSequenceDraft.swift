import Foundation

struct TaskSequenceEntryDraft: Identifiable, Hashable {
  let id: UUID
  var rawInput: String

  init(
    id: UUID = UUID(),
    rawInput: String = ""
  ) {
    self.id = id
    self.rawInput = rawInput
  }
}

struct TaskSequenceDraft: Hashable {
  var title: String
  var entries: [TaskSequenceEntryDraft]

  init(
    title: String = "",
    entries: [TaskSequenceEntryDraft] = [TaskSequenceEntryDraft()]
  ) {
    self.title = title
    self.entries = entries.isEmpty ? [TaskSequenceEntryDraft()] : entries
  }

  init(seedInput: String) {
    let trimmedInput = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
    self.init(entries: [TaskSequenceEntryDraft(rawInput: trimmedInput)])
  }
}
