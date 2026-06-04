import Foundation

public enum ByteSizeParserError: Error, Equatable {
    case invalid(String)
}

public enum ByteSizeParser {
    public static func parse(_ rawValue: String) throws -> Int64 {
        let cleaned = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        guard !cleaned.isEmpty else { throw ByteSizeParserError.invalid(rawValue) }

        let units: [(suffix: String, multiplier: Double)] = [
            ("gib", 1_073_741_824),
            ("gb", 1_073_741_824),
            ("g", 1_073_741_824),
            ("mib", 1_048_576),
            ("mb", 1_048_576),
            ("m", 1_048_576),
            ("kib", 1_024),
            ("kb", 1_024),
            ("k", 1_024),
            ("bytes", 1),
            ("byte", 1),
            ("b", 1)
        ]

        let match = units.first { cleaned.hasSuffix($0.suffix) }
        let numberPart: String
        let multiplier: Double
        if let match {
            numberPart = String(cleaned.dropLast(match.suffix.count))
            multiplier = match.multiplier
        } else {
            numberPart = cleaned
            multiplier = 1
        }

        guard let value = Double(numberPart), value >= 0, value.isFinite else {
            throw ByteSizeParserError.invalid(rawValue)
        }

        return Int64((value * multiplier).rounded())
    }
}
