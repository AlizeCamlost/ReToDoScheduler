import Foundation

protocol SyncSettingsRepositoryProtocol {
  func load() -> SyncSettings
  func save(_ settings: SyncSettings)
}
