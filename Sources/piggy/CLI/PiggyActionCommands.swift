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

struct MudMap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mudmap",
        abstract: "Mudmap: piggy mudmap [depth|all] [where]"
    )

    @Argument(help: "Optional depth/all then where, e.g. 1, 2 ~/Downloads, all ~/Downloads")
    var words: [String] = []

    @Option(name: .shortAndLong, help: "Number of entries to show inside each folder")
    var limit: Int = 30

    @Option(name: .long, help: "How many folder levels to draw. Default: 1. You can also write `piggy mudmap 2` or `piggy mudmap all`.")
    var depth: Int = FileTreeMapper.defaultMaxDepth

    @Flag(name: .long, help: "Include hidden files and folders")
    var includeHidden: Bool = false

    func run() throws {
        try runMudMap(words: words, limit: limit, depth: depth, includeHidden: includeHidden)
    }
}

struct Mud: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mud",
        abstract: "Alias for `piggy mudmap`",
        shouldDisplay: false
    )

    @Argument(help: .hidden)
    var words: [String] = []

    @Option(name: .shortAndLong, help: .hidden)
    var limit: Int = 30

    @Option(name: .long, help: .hidden)
    var depth: Int = FileTreeMapper.defaultMaxDepth

    @Flag(name: .long, help: .hidden)
    var includeHidden: Bool = false

    func run() throws {
        var mudWords = words
        if mudWords.first?.lowercased() == "map" { mudWords.removeFirst() }
        try runMudMap(words: mudWords, limit: limit, depth: depth, includeHidden: includeHidden)
    }
}

struct Map: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "map",
        abstract: "Alias for `piggy mudmap`",
        shouldDisplay: false
    )

    @Argument(help: .hidden)
    var words: [String] = []

    @Option(name: .shortAndLong, help: .hidden)
    var limit: Int = 30

    @Option(name: .long, help: .hidden)
    var depth: Int = FileTreeMapper.defaultMaxDepth

    @Flag(name: .long, help: .hidden)
    var includeHidden: Bool = false

    func run() throws {
        try runMudMap(words: words, limit: limit, depth: depth, includeHidden: includeHidden)
    }
}

struct Stye: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stye",
        abstract: "Legacy alias for `piggy mudmap`",
        shouldDisplay: false
    )

    @Argument(help: .hidden)
    var words: [String] = []

    @Option(name: .shortAndLong, help: .hidden)
    var limit: Int = 30

    @Option(name: .long, help: .hidden)
    var depth: Int = FileTreeMapper.defaultMaxDepth

    @Flag(name: .long, help: .hidden)
    var includeHidden: Bool = false

    func run() throws {
        try runMudMap(words: words, limit: limit, depth: depth, includeHidden: includeHidden)
    }
}

private struct MudMapInput {
    let words: [String]
    let depth: Int
    let depthLabel: String
}

private func resolveMudMapInputs(words: [String], fallbackDepth: Int) -> MudMapInput {
    var remaining = words
    var resolvedDepth = fallbackDepth
    var resolvedDepthLabel = mudMapDepthLabel(fallbackDepth)

    if let first = remaining.first, let depth = mudMapDepthArgument(first) {
        resolvedDepth = depth
        resolvedDepthLabel = mudMapDepthLabel(depth)
        remaining.removeFirst()
    } else if remaining.count > 1, let last = remaining.last, let depth = mudMapDepthArgument(last) {
        resolvedDepth = depth
        resolvedDepthLabel = mudMapDepthLabel(depth)
        remaining.removeLast()
    }

    return MudMapInput(words: remaining, depth: resolvedDepth, depthLabel: resolvedDepthLabel)
}

private func mudMapDepthArgument(_ raw: String) -> Int? {
    if raw.lowercased() == "all" { return Int.max }
    guard raw.allSatisfy({ $0.isNumber }), let depth = Int(raw) else { return nil }
    return max(0, depth)
}

private func mudMapDepthLabel(_ depth: Int) -> String {
    if depth == Int.max { return "all levels" }
    return depth == 1 ? "1 level" : "\(max(0, depth)) levels"
}

private func runMudMap(words: [String], limit: Int, depth: Int, includeHidden: Bool) throws {
    let input = resolveMudMapInputs(words: words, fallbackDepth: depth)
    let plan = try PiggyCommandPlan.parse(action: .mudmap, words: input.words)
    let root = URL(fileURLWithPath: (plan.where as NSString).expandingTildeInPath).standardizedFileURL
    let indicator = TerminalActivityIndicator(
        action: "🐽 Oink! Piggy is mapping \(input.depthLabel) of \"\(mudMapDisplayRoot(root))\"",
        doneLabel: piggyActivityDoneLabel(plan.action.rawValue)
    )
    indicator.start(root.path)
    let map = FileTreeMapper.map(
        root: root,
        maxDepth: input.depth,
        entriesPerFolder: limit,
        includeHidden: includeHidden
    )
    indicator.finish(map.summary.statusSummary)
    printMudMap(map, root: root, depth: input.depth, depthLabel: input.depthLabel, entriesPerFolder: limit, includeHidden: includeHidden)
}

private func printMudMap(_ map: FileTreeMap, root: URL, depth: Int, depthLabel: String, entriesPerFolder: Int, includeHidden: Bool) {
    print("")
    print(CLITheme.title("🐽 Mudmap of \"\(mudMapDisplayRoot(root))\""))
    print(CLITheme.separator("────────────────"))
    var notes: [String] = []
    if depth != FileTreeMapper.defaultMaxDepth || entriesPerFolder != 30 {
        notes.append("Depth: \(depthLabel) · Entries per folder: \(max(1, entriesPerFolder))")
    }
    if includeHidden {
        notes.append("Hidden Mac files are included this time.")
    }
    for note in notes {
        print("\(CLITheme.purple("•")) \(note)")
    }
    if !notes.isEmpty { print("") }
    print(CLITheme.mudMapName(map.root.name.isEmpty ? root.path : map.root.name, depth: 0, isDirectory: true) + CLITheme.dim("/ ") + CLITheme.size(ByteFormat.string(map.root.bytes), bytes: map.root.bytes) + mudMapInlineSummarySuffix(map.root) + mudMapInlineLimitSuffix(map.root, summarizedInline: map.root.childSummary != nil))
    if depth > 0 {
        printMudMapChildren(map.root.children, prefix: "", depth: 1, maxDepth: depth)
    }
    print("")
    print("\(CLITheme.label("Piggy mudmap summary")) \(CLITheme.dim("|")) \(CLITheme.label("folders")) \(map.summary.foldersVisited) \(CLITheme.dim("|")) \(CLITheme.label("files")) \(map.summary.filesMapped) \(CLITheme.dim("|")) \(CLITheme.label("scan total")) \(CLITheme.gold(ByteFormat.string(map.summary.totalBytes)))")
}

private func printMudMapChildren(_ nodes: [FileTreeNode], prefix: String, depth: Int, maxDepth: Int) {
    for (index, node) in nodes.enumerated() {
        let isLast = index == nodes.count - 1
        let branch = isLast ? "└── " : "├── "
        let nextPrefix = prefix + (isLast ? "    " : "│   ")
        let marker = node.isDirectory ? "/" : ""
        print("\(CLITheme.treeGuide(prefix + branch))\(CLITheme.mudMapName(node.name, depth: depth, isDirectory: node.isDirectory))\(CLITheme.dim(marker)) \(CLITheme.size(ByteFormat.string(node.bytes), bytes: node.bytes))\(mudMapInlineSummarySuffix(node))\(mudMapInlineLimitSuffix(node, summarizedInline: node.childSummary != nil))")
        if !node.children.isEmpty {
            printMudMapChildren(node.children, prefix: nextPrefix, depth: depth + 1, maxDepth: maxDepth)
        }
    }
}

private func countLabel(_ count: Int, _ singular: String) -> String {
    count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
}

private func mudMapInlineSummarySuffix(_ node: FileTreeNode) -> String {
    guard let summary = node.childSummary, summary.inlineOverview != nil else { return "" }
    var parts: [String] = []
    if summary.folderCount > 0 {
        parts.append("\(CLITheme.mudMapSummary(countLabel(summary.folderCount, "folder"), isFolders: true)) \(CLITheme.size(ByteFormat.string(summary.folderBytes), bytes: summary.folderBytes))")
    }
    if summary.fileCount > 0 {
        parts.append("\(CLITheme.mudMapSummary(countLabel(summary.fileCount, "file"), isFolders: false)) \(CLITheme.size(ByteFormat.string(summary.fileBytes), bytes: summary.fileBytes))")
    }
    return parts.isEmpty ? "" : CLITheme.dim(" · ") + parts.joined(separator: CLITheme.dim(" · "))
}

private func mudMapInlineLimitSuffix(_ node: FileTreeNode, summarizedInline: Bool = false) -> String {
    if summarizedInline, node.hiddenChildCount == 0 { return "" }
    guard let note = node.inlineLimitNote else { return "" }
    return CLITheme.dim("  \(note)")
}

private func mudMapDisplayRoot(_ root: URL) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    let path = root.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") { return "~" + String(path.dropFirst(home.count)) }
    return root.lastPathComponent.isEmpty ? path : root.lastPathComponent
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
        case .mudmap:
            try runMudMap(words: [plan.where], limit: limit, depth: FileTreeMapper.defaultMaxDepth, includeHidden: false)
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

        let items = scanFiles(what: plan.what, where: plan.where, sort: plan.sort, limit: limit, activity: plan.action.rawValue)
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

        let items = scanFiles(what: plan.what, where: plan.where, sort: plan.sort, limit: limit, activity: plan.action.rawValue)
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
        let items = scanFiles(what: scope, where: plan.where, sort: .big, limit: Int.max, activity: plan.action.rawValue)
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

    private static func scanFiles(what: PiggyWhat, where rawPath: String, sort: PiggySort, limit: Int, activity: String) -> [PiggyFileItem] {
        let root = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
        let exts = extensions(for: what)
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isHiddenKey, .isSymbolicLinkKey]
        let indicator = TerminalActivityIndicator(
            action: "🐽 Oink! Piggy is \(piggyActivityGerund(activity)) through \"\(displayWhere(rawPath))\" for \(what.canonical)",
            doneLabel: piggyActivityDoneLabel(activity)
        )
        indicator.start(root.path)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            indicator.finish("0 files")
            return []
        }

        var items: [PiggyFileItem] = []
        var seen = 0
        for case let url as URL in enumerator {
            seen += 1
            if seen == 1 || seen % 50 == 0 {
                indicator.update("\(seen) checked · \(TerminalActivityIndicator.clipped(url.lastPathComponent, to: 42))")
            }
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let ext = url.pathExtension.lowercased()
            if !exts.isEmpty && !exts.contains(ext) { continue }
            items.append(PiggyFileItem(url: url, root: root, bytes: Int64(values.fileSize ?? 0), modified: values.contentModificationDate))
        }
        indicator.finish("\(items.count) matched · \(seen) checked")

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
        guard !items.isEmpty else {
            print("🐽 No \(plan.what.canonical) found here.")
            return
        }
        print(CLITheme.title("🐽 \(plan.what.canonical.capitalized) snacks"))
        print(CLITheme.separator("──────────────────────────"))
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
        print(CLITheme.title("🐽 \(plan.what.canonical.capitalized) snacks\(queryText)"))
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
