import Foundation

struct TaskPoolOrganizationFileRepository: TaskPoolOrganizationRepositoryProtocol {
  private let fileManager: FileManager
  private let baseDirectory: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let dateProvider: () -> Date

  init(
    fileManager: FileManager = .default,
    baseDirectory: URL? = nil,
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.fileManager = fileManager
    self.baseDirectory = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    self.dateProvider = dateProvider

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    self.encoder = encoder
    self.decoder = JSONDecoder()
  }

  func load() throws -> TaskPoolOrganizationDocument {
    guard fileManager.fileExists(atPath: organizationFileURL.path) else {
      return TaskPoolOrganizationDocument.defaultValue(dateProvider: dateProvider)
    }

    let data = try Data(contentsOf: organizationFileURL)
    let record = try decoder.decode(TaskPoolOrganizationRecord.self, from: data)
    return record.toDomain()
  }

  func save(_ document: TaskPoolOrganizationDocument) throws {
    try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true, attributes: nil)
    let data = try encoder.encode(TaskPoolOrganizationRecord(document: document))
    try data.write(to: organizationFileURL, options: .atomic)
  }

  private var storageDirectory: URL {
    baseDirectory.appendingPathComponent("Norn", isDirectory: true)
  }

  private var organizationFileURL: URL {
    storageDirectory.appendingPathComponent("task-pool-organization.json")
  }
}
