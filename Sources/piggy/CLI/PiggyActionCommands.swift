import Foundation
import ArgumentParser
import PiggyKit

struct Sniff: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Quick look: piggy sniff [what] [where]"
    )

    @Argument(help: "What and where, e.g. apps, imgs ~/Pictures, docs ~/Documents")
    var words: [String] = []

    @Option(name: .shortAndLong, help: "Number of items to show")
    var limit: Int = 20

    @Flag(name: .long, help: "Force a fresh app scan when sniffing apps")
    var fresh: Bool = false

    func run() throws {
        let plan = try PiggyCommandPlan.parse(action: .sniff, words: words)
        try PiggyActionRunner.run(plan, limit: limit, fresh: fresh)
    }
}

struct Stye: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show the pigsty: piggy stye [where]"
    )

    @Argument(help: "Where to map. Defaults to the current folder.")
    var words: [String] = []

    @Option(name: .shortAndLong, help: "Number of folders to show")
    var limit: Int = 25

    func run() throws {
        let plan = try PiggyCommandPlan.parse(action: .stye, words: words)
        let folders = Folders.parseOrExit([plan.where, "--limit", "\(limit)", "--depth", "2", "--activity", plan.action.rawValue])
        try folders.run()
    }
}

enum PiggyActionRunner {
    static func run(_ plan: PiggyCommandPlan, limit: Int = 20, fresh: Bool = false) throws {
        switch plan.action {
        case .sniff:
            try runSniff(plan, limit: limit, fresh: fresh)
        case .snort:
            try runSnort(plan, limit: limit, fresh: fresh)
        case .search:
            try runSearch(plan, limit: limit)
        case .stye:
            let folders = Folders.parseOrExit([plan.where, "--limit", "\(limit)", "--depth", "2", "--activity", plan.action.rawValue])
            try folders.run()
        }
    }

    private static func runSniff(_ plan: PiggyCommandPlan, limit: Int, fresh: Bool) throws {
        if plan.what == .apps {
            let args = listArgs(for: plan.sort, fresh: fresh, activity: plan.action.rawValue)
            let list = List.parseOrExit(args)
            try list.run()
            return
        }

        if plan.what == .everything {
            let folders = Folders.parseOrExit([plan.where, "--limit", "\(limit)", "--activity", plan.action.rawValue])
            try folders.run()
            return
        }

        let items = scanFiles(what: plan.what, where: plan.where, sort: plan.sort, limit: limit)
        printFileTable(items, plan: plan)
    }

    private static func runSnort(_ plan: PiggyCommandPlan, limit: Int, fresh: Bool) throws {
        if plan.what == .apps {
            let args = listArgs(for: plan.sort, fresh: fresh, activity: plan.action.rawValue)
            let list = List.parseOrExit(args)
            try list.run()
            return
        }

        if plan.what == .everything {
            let folders = Folders.parseOrExit([plan.where, "--limit", "\(limit)", "--depth", "2", "--activity", plan.action.rawValue])
            try folders.run()
            return
        }

        let items = scanFiles(what: plan.what, where: plan.where, sort: plan.sort, limit: limit)
        printFileCards(items, plan: plan)
    }

    private static func runSearch(_ plan: PiggyCommandPlan, limit: Int) throws {
        guard let query = plan.query else { throw PiggyCommandPlanError.missingSearchQuery }
        if plan.what == .apps {
            let search = Search.parseOrExit([query])
            try search.runLegacyAppSearch()
            return
        }

        let scope = plan.what == .everything ? .everything : plan.what
        let items = scanFiles(what: scope, where: plan.where, sort: .big, limit: Int.max)
            .filter { $0.name.localizedCaseInsensitiveContains(query) || $0.displayPath.localizedCaseInsensitiveContains(query) }
            .prefix(limit)
        printFileCards(Array(items), plan: plan)
    }

    private static func listArgs(for sort: PiggySort, fresh: Bool, activity: String) -> [String] {
        var args: [String]
        switch sort {
        case .big: args = ["--sort", "size"]
        case .small: args = ["--sort", "size", "--asc"]
        case .new: args = ["--sort", "modified"]
        case .old: args = ["--sort", "modified", "--asc"]
        }
        if fresh { args.append("--fresh") }
        args.append(contentsOf: ["--activity", activity])
        return args
    }

    private static func scanFiles(what: PiggyWhat, where rawPath: String, sort: PiggySort, limit: Int) -> [PiggyFileItem] {
        let root = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
        let exts = extensions(for: what)
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isHiddenKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        var items: [PiggyFileItem] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let ext = url.pathExtension.lowercased()
            if !exts.isEmpty && !exts.contains(ext) { continue }
            items.append(PiggyFileItem(url: url, root: root, bytes: Int64(values.fileSize ?? 0), modified: values.contentModificationDate))
        }

        items.sort { lhs, rhs in
            switch sort {
            case .big: return lhs.bytes == rhs.bytes ? lhs.name < rhs.name : lhs.bytes > rhs.bytes
            case .small: return lhs.bytes == rhs.bytes ? lhs.name < rhs.name : lhs.bytes < rhs.bytes
            case .new: return (lhs.modified ?? .distantPast) > (rhs.modified ?? .distantPast)
            case .old: return (lhs.modified ?? .distantFuture) < (rhs.modified ?? .distantFuture)
            }
        }
        return Array(items.prefix(max(0, limit)))
    }

    private static func extensions(for what: PiggyWhat) -> Set<String> {
        switch what {
        case .everything: return []
        case .apps: return []
        case .imgs: return ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg"]
        case .vids: return ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv"]
        case .docs: return ["pdf", "doc", "docx", "pages", "txt", "rtf", "md", "csv", "xls", "xlsx", "ppt", "pptx", "key"]
        }
    }

    private static func printFileTable(_ items: [PiggyFileItem], plan: PiggyCommandPlan) {
        print("")
        print(CLITheme.title("🐽 Piggy is sniffing through \"\(displayWhere(plan.where))\" for \(plan.what.canonical)"))
        print(CLITheme.separator("──────────────────────────"))
        print("\(CLITheme.purple("•")) Just looking: Piggy did not move, edit, or trash anything.")
        print("\(CLITheme.purple("•")) Grammar: \(CLITheme.command("piggy [action] [what] [where]"))")
        print("")
        guard !items.isEmpty else {
            print("🐽 No \(plan.what.canonical) found here.")
            return
        }
        let nameW = min(max(items.map(\.name.count).max() ?? 12, 12), 36)
        print("#   \(pad("Size", 10))  \(pad("What", nameW))  Where")
        print(String(repeating: "─", count: min(90, nameW + 30)))
        for (index, item) in items.enumerated() {
            print("\(pad("\(index + 1).", 3)) \(pad(ByteFormat.string(item.bytes), 10))  \(pad(ellipsize(item.name, width: nameW), nameW))  \(item.displayPath)")
        }
    }

    private static func printFileCards(_ items: [PiggyFileItem], plan: PiggyCommandPlan) {
        print("")
        let queryText = plan.query.map { " matching \"\($0)\"" } ?? ""
        print(CLITheme.title("🐽 Piggy is \(piggyActivityGerund(plan.action.rawValue)) through \"\(displayWhere(plan.where))\" for \(plan.what.canonical)\(queryText)"))
        print(CLITheme.separator("──────────────────────────"))
        guard !items.isEmpty else {
            print("No matching stuff found.")
            return
        }
        for (index, item) in items.enumerated() {
            print("\n  \(index + 1). \(CLITheme.path(item.name))")
            print("     \(CLITheme.label("Size:"))   \(CLITheme.size(ByteFormat.string(item.bytes), bytes: item.bytes))")
            if let modified = item.modified { print("     \(CLITheme.label("New:"))    \(fileRelativeLabel(modified))") }
            print("     \(CLITheme.label("Where:"))  \(CLITheme.path(item.displayPath))")
        }
    }

    private static func displayWhere(_ raw: String) -> String {
        if raw == "." { return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent }
        let expanded = (raw as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if url.path == home { return "Home" }
        return url.lastPathComponent.isEmpty ? raw : url.lastPathComponent
    }

    private static func pad(_ value: String, _ width: Int) -> String {
        value.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    private static func ellipsize(_ text: String, width: Int) -> String {
        guard text.count > width else { return text }
        return String(text.prefix(max(0, width - 1))) + "…"
    }

    private static func fileRelativeLabel(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 2_592_000 { return "\(Int(interval / 86_400))d ago" }
        if interval < 31_536_000 { return "\(Int(interval / 2_592_000))m ago" }
        return "\(Int(interval / 31_536_000))y ago"
    }
}

private struct PiggyFileItem {
    let url: URL
    let root: URL
    let bytes: Int64
    let modified: Date?

    var name: String { url.lastPathComponent }

    var displayPath: String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if path.hasPrefix(rootPath + "/") { return String(path.dropFirst(rootPath.count + 1)) }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}
