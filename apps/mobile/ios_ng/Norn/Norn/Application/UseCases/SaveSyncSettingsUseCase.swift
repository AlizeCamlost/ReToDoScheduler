import Foundation

struct SaveSyncSettingsUseCase {
  private let repository: any SyncSettingsRepositoryProtocol
  private let idGenerator: () -> String

  init(
    repository: any SyncSettingsRepositoryProtocol,
    idGenerator: @escaping () -> String = { UUID().uuidString }
  ) {
    self.repository = repository
    self.idGenerator = idGenerator
  }

  func execute(settings: SyncSettings) -> SyncSettings {
    let normalizedSettings = SyncSettings(
      baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
      authToken: settings.authToken.trimmingCharacters(in: .whitespacesAndNewlines),
      deviceID: settings.deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? idGenerator()
        : settings.deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    repository.save(normalizedSettings)
    return normalizedSettings
  }
}
