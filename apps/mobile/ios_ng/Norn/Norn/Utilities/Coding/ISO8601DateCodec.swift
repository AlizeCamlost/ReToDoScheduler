import Foundation

enum ISO8601DateCodec {
  private static let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static func encode(_ date: Date?) -> String? {
    guard let date else { return nil }
    return formatter.string(from: date)
  }

  static func decode(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }
}
