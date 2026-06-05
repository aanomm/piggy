import Foundation

public enum PiggyAction: String, Equatable, Sendable {
    case sniff
    case snort
    case search
    case stye
}

public enum PiggyWhat: String, Equatable, Sendable, CaseIterable {
    case everything
    case apps
    case imgs
    case vids
    case docs

    public var canonical: String {
        switch self {
        case .everything: return "everything"
        case .apps: return "apps"
        case .imgs: return "imgs"
        case .vids: return "vids"
        case .docs: return "docs"
        }
    }

    public static func parse(_ raw: String) -> PiggyWhat? {
        switch raw.lowercased() {
        case "all", "everything", "stuff", "files": return .everything
        case "app", "apps", "application", "applications": return .apps
        case "img", "imgs", "image", "images", "photo", "photos", "pic", "pics": return .imgs
        case "vid", "vids", "video", "videos", "movie", "movies": return .vids
        case "doc", "docs", "document", "documents", "pdf", "pdfs": return .docs
        default: return nil
        }
    }
}

public enum PiggySort: String, Equatable, Sendable {
    case big
    case small
    case new
    case old

    public static func parse(_ raw: String) -> PiggySort? {
        switch raw.lowercased() {
        case "big", "biggest", "fat", "fattest", "large", "largest": return .big
        case "small", "smallest", "tiny": return .small
        case "new", "newest", "recent": return .new
        case "old", "oldest", "stale": return .old
        default: return nil
        }
    }
}

public enum PiggyCommandPlanError: Error, Equatable {
    case missingSearchQuery
}

public struct PiggyCommandPlan: Equatable, Sendable {
    public let action: PiggyAction
    public let what: PiggyWhat
    public let `where`: String
    public let sort: PiggySort
    public let query: String?

    public init(action: PiggyAction, what: PiggyWhat, where: String, sort: PiggySort = .big, query: String? = nil) {
        self.action = action
        self.what = what
        self.where = `where`
        self.sort = sort
        self.query = query
    }

    public static func parse(action: PiggyAction, words: [String]) throws -> PiggyCommandPlan {
        var remaining = words.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var what: PiggyWhat = .everything
        var sort: PiggySort = .big
        var whereValue = "."

        if let first = remaining.first, let parsed = PiggyWhat.parse(first) {
            what = parsed
            remaining.removeFirst()
        }

        switch action {
        case .search:
            if let last = remaining.last, looksLikeWhere(last), remaining.count > 1 {
                whereValue = last
                remaining.removeLast()
            }
            let query = remaining.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { throw PiggyCommandPlanError.missingSearchQuery }
            return PiggyCommandPlan(action: action, what: what, where: whereValue, sort: sort, query: query)

        case .stye:
            if let first = remaining.first {
                whereValue = first
            }
            return PiggyCommandPlan(action: action, what: .everything, where: whereValue, sort: .big)

        case .sniff, .snort:
            if let first = remaining.first, let parsedSort = PiggySort.parse(first) {
                sort = parsedSort
                remaining.removeFirst()
            }
            if let first = remaining.first {
                whereValue = first
            }
            return PiggyCommandPlan(action: action, what: what, where: whereValue, sort: sort)
        }
    }

    public static func looksLikeWhere(_ raw: String) -> Bool {
        if raw == "." || raw == ".." || raw.hasPrefix("/") || raw.hasPrefix("~/") || raw.hasPrefix("./") || raw.hasPrefix("../") {
            return true
        }
        return FileManager.default.fileExists(atPath: (raw as NSString).expandingTildeInPath)
    }
}
