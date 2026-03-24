import Foundation

struct QuickAddDraft: Hashable {
  var rawInput: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var tags: [String]

  init(
    rawInput: String,
    title: String,
    estimatedMinutes: Int = 30,
    minChunkMinutes: Int = 25,
    dueAt: Date? = nil,
    tags: [String] = []
  ) {
    self.rawInput = rawInput
    self.title = title
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dueAt = dueAt
    self.tags = tags
  }
}

extension QuickAddDraft {
  static func parse(
    rawInput: String,
    dateProvider: @escaping () -> Date = Date.init
  ) -> QuickAddDraft? {
    let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      return nil
    }

    return QuickAddDraft(
      rawInput: trimmedInput,
      title: sanitizeTitle(trimmedInput),
      estimatedMinutes: parseDuration(from: trimmedInput, fallback: 30),
      minChunkMinutes: parseMinChunk(from: trimmedInput),
      dueAt: parseDueAt(from: trimmedInput, dateProvider: dateProvider),
      tags: parseTags(from: trimmedInput)
    )
  }

  var taskDraft: TaskDraft {
    TaskDraft(
      title: title,
      rawInput: rawInput,
      estimatedMinutes: estimatedMinutes,
      minChunkMinutes: minChunkMinutes,
      dueAt: dueAt,
      tags: tags
    )
  }

  private static func sanitizeTitle(_ source: String) -> String {
    let durationPatterns = [
      #"\b\d+\s*(?:分钟|mins?|minutes?)\b"#,
      #"\b\d+\s*m\b"#,
      #"\b\d+\s*h\b"#
    ]
    let minChunkPatterns = [
      #"至少\s*\d+\s*分钟"#,
      #"最少\s*\d+\s*分钟"#,
      #"min\s*chunk\s*\d+"#
    ]
    let duePatterns = [
      #"今天"#,
      #"明天"#,
      #"后天"#,
      #"(?i)\btoday\b"#,
      #"(?i)\btomorrow\b"#,
      #"\b\d{4}-\d{1,2}-\d{1,2}\b"#
    ]

    var title = source.replacingOccurrences(of: #"#[\w\u4e00-\u9fa5-]+"#, with: "", options: .regularExpression)
    for pattern in durationPatterns + minChunkPatterns + duePatterns {
      title = title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    let normalized = title
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? "Untitled Task" : normalized
  }

  private static func parseDuration(from source: String, fallback: Int) -> Int {
    let patterns = [
      #"(\\d+)\\s*(?:分钟|mins?|minutes?)"#,
      #"(\\d+)\\s*m\\b"#,
      #"(\\d+)\\s*h\\b"#
    ]

    for pattern in patterns {
      guard let minutes = firstMatch(in: source, pattern: pattern) else {
        continue
      }

      if pattern.contains("\\s*h\\b") {
        return minutes * 60
      }
      return minutes
    }

    return fallback
  }

  private static func parseMinChunk(from source: String) -> Int {
    let patterns = [
      #"至少\s*(\d+)\s*分钟"#,
      #"最少\s*(\d+)\s*分钟"#,
      #"min\s*chunk\s*(\d+)"#
    ]

    for pattern in patterns {
      if let value = firstMatch(in: source, pattern: pattern) {
        return value
      }
    }

    return 25
  }

  private static func parseDueAt(
    from source: String,
    dateProvider: @escaping () -> Date
  ) -> Date? {
    let calendar = Calendar.current
    let now = dateProvider()
    let startOfToday = calendar.startOfDay(for: now)

    if source.contains("今天") || source.range(of: #"\btoday\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
      return startOfToday
    }
    if source.contains("明天") || source.range(of: #"\btomorrow\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
      return calendar.date(byAdding: .day, value: 1, to: startOfToday)
    }
    if source.contains("后天") {
      return calendar.date(byAdding: .day, value: 2, to: startOfToday)
    }

    guard let match = source.range(of: #"\b\d{4}-\d{1,2}-\d{1,2}\b"#, options: .regularExpression) else {
      return nil
    }

    let dateText = String(source[match])
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-M-d"
    return formatter.date(from: dateText)
  }

  private static func parseTags(from source: String) -> [String] {
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let regex = try? NSRegularExpression(pattern: #"#[\w\u4e00-\u9fa5-]+"#, options: []) else {
      return []
    }

    return regex.matches(in: source, options: [], range: range).compactMap { match in
      guard let range = Range(match.range, in: source) else {
        return nil
      }
      return String(source[range]).replacingOccurrences(of: "#", with: "").lowercased()
    }
  }

  private static func firstMatch(in source: String, pattern: String) -> Int? {
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    guard
      let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
      let match = regex.firstMatch(in: source, options: [], range: range),
      match.numberOfRanges > 1,
      let capturedRange = Range(match.range(at: 1), in: source)
    else {
      return nil
    }

    return Int(source[capturedRange])
  }
}
