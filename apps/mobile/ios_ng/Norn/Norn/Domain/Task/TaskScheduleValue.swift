import Foundation

struct TaskScheduleValue: Hashable, Codable {
  var rewardOnTime: Int
  var penaltyMissed: Int

  static let `default` = TaskScheduleValue(
    rewardOnTime: 10,
    penaltyMissed: 25
  )
}
