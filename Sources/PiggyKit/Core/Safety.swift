import Foundation

public enum SafetyLevel: String, Codable, Comparable {
    case safeReview
    case cautious
    case sensitive
    case blocked

    private var rank: Int {
        switch self {
        case .safeReview: return 0
        case .cautious: return 1
        case .sensitive: return 2
        case .blocked: return 3
        }
    }

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct SafetyAssessment: Codable, Equatable {
    public let level: SafetyLevel
    public let reason: String

    public init(level: SafetyLevel, reason: String) {
        self.level = level
        self.reason = reason
    }
}

public enum SafetyClassifier {
    public static func assess(path rawPath: String, homeDirectory: String = NSHomeDirectory()) -> SafetyAssessment {
        let path = standardize(rawPath)
        let home = standardize(homeDirectory)

        if path == "/" || path.hasPrefix("/System/") || path == "/System" {
            return SafetyAssessment(level: .blocked, reason: "System paths are never removable by Piggy.")
        }

        if path.hasPrefix("/private/var/db/") || path.hasPrefix("/var/db/") {
            return SafetyAssessment(level: .blocked, reason: "macOS database paths are protected.")
        }

        if path.hasPrefix("/Applications/") || path.hasPrefix("\(home)/Applications/") {
            return SafetyAssessment(level: .cautious, reason: "Applications can be trashed after explicit confirmation.")
        }

        if path.hasPrefix("\(home)/Library/Mobile Documents/") ||
            path.hasPrefix("\(home)/Library/CloudStorage/") ||
            path.hasPrefix("\(home)/Library/Group Containers/group.com.apple") {
            return SafetyAssessment(level: .sensitive, reason: "Cloud, iCloud, or Apple group-container paths require extra caution.")
        }

        if path.hasPrefix("\(home)/Library/Containers/") ||
            path.hasPrefix("\(home)/Library/Group Containers/") ||
            path.hasPrefix("\(home)/Library/Application Support/") {
            return SafetyAssessment(level: .cautious, reason: "App data paths may contain user data.")
        }

        if path.hasPrefix("\(home)/Library/Caches/") ||
            path.hasPrefix("\(home)/Library/Logs/") ||
            path.hasPrefix("\(home)/Library/Saved Application State/") {
            return SafetyAssessment(level: .safeReview, reason: "Cache, log, and saved-state paths are usually safe to review.")
        }

        if path.hasPrefix("\(home)/Library/Preferences/") {
            return SafetyAssessment(level: .cautious, reason: "Preference files are small but can reset app configuration.")
        }

        return SafetyAssessment(level: .cautious, reason: "Unrecognized paths require review before action.")
    }

    private static func standardize(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
