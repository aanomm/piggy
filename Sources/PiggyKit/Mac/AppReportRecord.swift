import Foundation

public struct AppReportRecord: Codable, Equatable {
    public let name: String
    public let bundleID: String?
    public let path: String
    public let sizeBytes: Int64
    public let sizeFormatted: String
    public let architecture: String
    public let architectureLabel: String
    public let scope: String
    public let installedBy: String
    public let flagged: [String]
    public let version: String?
    public let build: String?
    public let minMacOS: String?
    public let purpose: String?
    public let appleSigned: Bool
    public let appStore: Bool
    public let quarantined: Bool
    public let helpers: Int
    public let bundledAt: Date?
    public let modifiedAt: Date?
    public let lastUsedAt: Date?

    public init(app: AppInfo) {
        self.name = app.displayName
        self.bundleID = app.bundleIdentifier
        self.path = app.path.standardizedFileURL.path
        self.sizeBytes = app.size
        self.sizeFormatted = app.formattedSize
        self.architecture = app.architecture.rawValue
        self.architectureLabel = app.architecture.label
        self.scope = app.sourceLabel
        self.installedBy = app.originLabel
        self.flagged = app.flagReasons
        self.version = app.shortVersion
        self.build = app.bundleVersion
        self.minMacOS = app.minOSVersion
        self.purpose = app.purpose
        self.appleSigned = app.isAppleSigned
        self.appStore = app.isFromAppStore
        self.quarantined = app.isQuarantined
        self.helpers = app.agentCount
        self.bundledAt = app.creationDate
        self.modifiedAt = app.modificationDate
        self.lastUsedAt = app.lastUsedDate
    }

    enum CodingKeys: String, CodingKey {
        case name
        case bundleID = "bundle_id"
        case path
        case sizeBytes = "size_bytes"
        case sizeFormatted = "size_formatted"
        case architecture
        case architectureLabel = "architecture_label"
        case scope
        case installedBy = "installed_by"
        case flagged
        case version
        case build
        case minMacOS = "min_macos"
        case purpose
        case appleSigned = "apple_signed"
        case appStore = "app_store"
        case quarantined
        case helpers
        case bundledAt = "bundled_at"
        case modifiedAt = "modified_at"
        case lastUsedAt = "last_used_at"
    }

    public static func encodeJSON(_ apps: [AppInfo]) throws -> String {
        try encodeJSONRecords(apps.map(AppReportRecord.init(app:)))
    }

    public static func encodeJSONObject(_ app: AppInfo) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(AppReportRecord(app: app))
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public static func encodeJSONRecords(_ records: [AppReportRecord]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

public extension AppInfo {
    var flagReasons: [String] {
        var reasons: [String] = []
        if architecture == .i386 { reasons.append("Incompatible") }
        else if architecture == .x86_64 { reasons.append("Rosetta") }
        if isQuarantined { reasons.append("Downloaded") }
        return reasons
    }

    var flagSummary: String {
        flagReasons.isEmpty ? "-" : flagReasons.joined(separator: ", ")
    }
}
