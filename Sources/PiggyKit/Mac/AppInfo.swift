import Foundation

public enum Architecture: String, CaseIterable, Codable {
    case arm64
    case x86_64
    case universal
    case i386
    case unknown

    public var label: String {
        switch self {
        case .arm64: return "arm64 (Apple Silicon)"
        case .x86_64: return "x86_64 (Intel/Rosetta)"
        case .universal: return "Universal (arm64 + x86_64)"
        case .i386: return "32-bit (Dead)"
        case .unknown: return "Unknown"
        }
    }

    public var shortLabel: String {
        switch self {
        case .arm64: return "arm64"
        case .x86_64: return "x86_64"
        case .universal: return "Uni"
        case .i386: return "32-bit"
        case .unknown: return "?"
        }
    }
}

public struct AppInfo: Identifiable, Codable {
    public let id: String
    public let path: URL
    public let displayName: String
    public let bundleIdentifier: String?
    public let bundleVersion: String?
    public let shortVersion: String?
    public let minOSVersion: String?
    public let size: Int64
    public let creationDate: Date?
    public let modificationDate: Date?
    public let lastUsedDate: Date?
    public let purpose: String?
    public let architecture: Architecture
    public let isAppleSigned: Bool
    public let isFromAppStore: Bool
    public let isQuarantined: Bool
    public let agentCount: Int
    public let sourceDir: SourceDirectory

    public init(
        id: String,
        path: URL,
        displayName: String,
        bundleIdentifier: String?,
        bundleVersion: String?,
        shortVersion: String?,
        minOSVersion: String?,
        size: Int64,
        creationDate: Date?,
        modificationDate: Date?,
        lastUsedDate: Date?,
        purpose: String?,
        architecture: Architecture,
        isAppleSigned: Bool,
        isFromAppStore: Bool,
        isQuarantined: Bool,
        agentCount: Int,
        sourceDir: SourceDirectory
    ) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.shortVersion = shortVersion
        self.minOSVersion = minOSVersion
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastUsedDate = lastUsedDate
        self.purpose = purpose
        self.architecture = architecture
        self.isAppleSigned = isAppleSigned
        self.isFromAppStore = isFromAppStore
        self.isQuarantined = isQuarantined
        self.agentCount = agentCount
        self.sourceDir = sourceDir
    }

    public enum SourceDirectory: String, CaseIterable, Codable {
        case system = "/System/Applications"
        case rootApp = "/Applications"
        case userApp = "~/Applications"

        public var label: String {
            switch self {
            case .system: return "System"
            case .rootApp: return "System-wide"
            case .userApp: return "User"
            }
        }

        public var path: String {
            switch self {
            case .system: return "/System/Applications"
            case .rootApp: return "/Applications"
            case .userApp: return "\(NSHomeDirectory())/Applications"
            }
        }
    }

    public var partyLabel: String {
        if isAppleSigned { return "Apple" }
        return "3rd Party"
    }

    public var originLabel: String {
        if isAppleSigned { return "Apple" }
        if isFromAppStore { return "App Store" }
        return "Direct"
    }

    public var formattedSize: String {
        ByteFormat.string(size)
    }

    public var formattedSizePad: String {
        formattedSize.padding(toLength: 9, withPad: " ", startingAt: 0)
    }

    public var sourceLabel: String {
        let url = path.standardizedFileURL
        if url.path.hasPrefix(SourceDirectory.system.path) { return SourceDirectory.system.label }
        if url.path.hasPrefix(SourceDirectory.userApp.path) { return SourceDirectory.userApp.label }
        return SourceDirectory.rootApp.label
    }
}

// MARK: - Sort Keys

public enum SortKey: String, CaseIterable {
    case size
    case name
    case created
    case modified
    case used
    case architecture
    case version
    case store
    case agents

    public var label: String {
        switch self {
        case .size: return "Size"
        case .name: return "Name"
        case .created: return "Bundle Date"
        case .modified: return "Modified"
        case .used: return "Last Used"
        case .architecture: return "Arch"
        case .version: return "Version"
        case .store: return "Origin"
        case .agents: return "Agents"
        }
    }

    public var sortKeyChar: Character {
        switch self {
        case .size: return "s"
        case .name: return "n"
        case .created: return "c"
        case .modified: return "m"
        case .used: return "u"
        case .architecture: return "a"
        case .version: return "v"
        case .store: return "o"
        case .agents: return "b"
        }
    }

    public init?(argument: String) {
        switch argument.lowercased() {
        case "arch": self = .architecture
        default: self.init(rawValue: argument.lowercased())
        }
    }

    public init?(char: Character) {
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
        default: return nil
        }
    }

    public static func comparator(_ key: SortKey, ascending: Bool) -> (AppInfo, AppInfo) -> Bool {
        switch key {
        case .size:
            return { ascending ? $0.size < $1.size : $0.size > $1.size }
        case .name:
            return {
                let comparison = $0.displayName.localizedStandardCompare($1.displayName)
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }
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
