import Foundation

enum Architecture: String, CaseIterable, Codable {
    case arm64
    case x86_64
    case universal
    case i386
    case unknown

    var label: String {
        switch self {
        case .arm64:    return "arm64 (Apple Silicon)"
        case .x86_64:   return "x86_64 (Intel/Rosetta)"
        case .universal: return "Universal (arm64 + x86_64)"
        case .i386:     return "32-bit (Dead)"
        case .unknown:  return "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .arm64:    return "arm64"
        case .x86_64:   return "x86_64"
        case .universal: return "Uni"
        case .i386:     return "32-bit"
        case .unknown:  return "?"
        }
    }
}

struct AppInfo: Identifiable, Codable {
    let id: String
    let path: URL
    let displayName: String
    let bundleIdentifier: String?
    let bundleVersion: String?
    let shortVersion: String?
    let minOSVersion: String?
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let lastUsedDate: Date?
    let purpose: String?
    let architecture: Architecture
    let isAppleSigned: Bool
    let isFromAppStore: Bool
    let isQuarantined: Bool
    let agentCount: Int
    let sourceDir: SourceDirectory

    enum SourceDirectory: String, CaseIterable, Codable {
        case system      = "/System/Applications"
        case rootApp     = "/Applications"
        case userApp     = "~/Applications"

        var label: String {
            switch self {
            case .system:  return "System"
            case .rootApp: return "System-wide"
            case .userApp: return "User"
            }
        }

        var path: String {
            switch self {
            case .system:  return "/System/Applications"
            case .rootApp: return "/Applications"
            case .userApp: return "\(NSHomeDirectory())/Applications"
            }
        }
    }

    var partyLabel: String {
        if isAppleSigned { return "Apple" }
        return "3rd Party"
    }

    var originLabel: String {
        if isAppleSigned { return "Apple" }
        if isFromAppStore { return "App Store" }
        return "Direct"
    }

    var formattedSize: String {
        let absSize = abs(size)
        switch absSize {
        case 0..<1024:
            return "\(size) B"
        case 1024..<1_048_576:
            return String(format: "%.1f KB", Double(absSize) / 1024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        default:
            return String(format: "%.2f GB", Double(absSize) / 1_073_741_824)
        }
    }

    var formattedSizePad: String {
        formattedSize.padding(toLength: 9, withPad: " ", startingAt: 0)
    }

    var sourceLabel: String {
        let url = path.standardizedFileURL
        if url.path.hasPrefix(SourceDirectory.system.path) { return SourceDirectory.system.label }
        if url.path.hasPrefix(SourceDirectory.userApp.path) { return SourceDirectory.userApp.label }
        return SourceDirectory.rootApp.label
    }
}

// MARK: - Sort Keys

enum SortKey: String, CaseIterable {
    case size
    case name
    case created
    case modified
    case used
    case architecture
    case version
    case store
    case agents

    var label: String {
        switch self {
        case .size:         return "Size"
        case .name:         return "Name"
        case .created:      return "Created"
        case .modified:     return "Modified"
        case .used:         return "Last Used"
        case .architecture: return "Arch"
        case .version:      return "Version"
        case .store:        return "Origin"
        case .agents:       return "Agents"
        }
    }

    var sortKeyChar: Character {
        switch self {
        case .size:         return "s"
        case .name:         return "n"
        case .created:      return "c"
        case .modified:     return "m"
        case .used:         return "u"
        case .architecture: return "a"
        case .version:      return "v"
        case .store:        return "o"
        case .agents:       return "b"
        }
    }

    init?(char: Character) {
        switch char {
        case "s": self = .size
        case "n": self = .name
        case "c": self = .created
        case "m": self = .modified
        case "u": self = .used
        case "a": self = .architecture
        case "v": self = .version
        case "o": self = .store
        case "b": self = .agents
        default:  return nil
        }
    }

    static func comparator(_ key: SortKey, ascending: Bool) -> (AppInfo, AppInfo) -> Bool {
        switch key {
        case .size:
            return { ascending ? $0.size < $1.size : $0.size > $1.size }
        case .name:
            return { ascending ? $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending : $0.displayName.localizedStandardCompare($1.displayName) == .orderedDescending }
        case .created:
            return { compareDates($0.creationDate, $1.creationDate, ascending) }
        case .modified:
            return { compareDates($0.modificationDate, $1.modificationDate, ascending) }
        case .used:
            return { compareDates($0.lastUsedDate, $1.lastUsedDate, ascending) }
        case .architecture:
            return { ascending ? $0.architecture.rawValue < $1.architecture.rawValue : $0.architecture.rawValue > $1.architecture.rawValue }
        case .version:
            return { ascending ? ($0.shortVersion ?? "") < ($1.shortVersion ?? "") : ($0.shortVersion ?? "") > ($1.shortVersion ?? "") }
        case .store:
            return { ascending ? $0.isFromAppStore && !$1.isFromAppStore : $1.isFromAppStore && !$0.isFromAppStore }
        case .agents:
            return { ascending ? $0.agentCount < $1.agentCount : $0.agentCount > $1.agentCount }
        }
    }
}

private func compareDates(_ a: Date?, _ b: Date?, _ ascending: Bool) -> Bool {
    switch (a, b) {
    case (.some(let da), .some(let db)):
        return ascending ? da < db : da > db
    case (.none, .some), (.none, .none):
        return ascending
    case (.some, .none):
        return !ascending
    }
}
