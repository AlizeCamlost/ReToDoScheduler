import Foundation

struct UserDefaultsSyncSettingsRepository: SyncSettingsRepositoryProtocol {
  private enum Key: String {
    case baseURL = "norn.sync.base_url"
    case authToken = "norn.sync.auth_token"
    case deviceID = "norn.sync.device_id"
  }

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func load() -> SyncSettings {
    SyncSettings(
      baseURL: userDefaults.string(forKey: Key.baseURL.rawValue) ?? "",
      authToken: userDefaults.string(forKey: Key.authToken.rawValue) ?? "",
      deviceID: userDefaults.string(forKey: Key.deviceID.rawValue) ?? ""
    )
  }

  func save(_ settings: SyncSettings) {
    userDefaults.set(settings.baseURL, forKey: Key.baseURL.rawValue)
    userDefaults.set(settings.authToken, forKey: Key.authToken.rawValue)
    userDefaults.set(settings.deviceID, forKey: Key.deviceID.rawValue)
  }
}
