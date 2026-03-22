import Foundation

enum SyncStatus: Equatable {
  case notConfigured
  case idle(lastSyncedAt: Date?)
  case syncing
  case failed(message: String)
}
