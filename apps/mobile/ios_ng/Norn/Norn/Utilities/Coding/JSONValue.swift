import Foundation

indirect enum JSONValue: Hashable, Codable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let object = try? container.decode([String: JSONValue].self) {
      self = .object(object)
    } else if let array = try? container.decode([JSONValue].self) {
      self = .array(array)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }

  var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  var intValue: Int? {
    switch self {
    case .number(let value):
      return Int(value)
    case .string(let value):
      return Int(value)
    default:
      return nil
    }
  }

  var objectValue: [String: JSONValue]? {
    guard case .object(let value) = self else { return nil }
    return value
  }
}
