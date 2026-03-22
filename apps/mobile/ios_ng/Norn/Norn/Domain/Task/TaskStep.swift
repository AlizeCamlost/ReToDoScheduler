import Foundation

struct TaskStep: Identifiable, Hashable, Codable {
  let id: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dependsOnStepIDs: [String]

  init(
    id: String,
    title: String,
    estimatedMinutes: Int,
    minChunkMinutes: Int,
    dependsOnStepIDs: [String] = []
  ) {
    self.id = id
    self.title = title
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dependsOnStepIDs = dependsOnStepIDs
  }
}
