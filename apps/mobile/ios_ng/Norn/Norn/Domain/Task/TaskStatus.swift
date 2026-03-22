import Foundation

enum TaskStatus: String, CaseIterable, Codable {
  case todo
  case doing
  case done
  case archived
}
