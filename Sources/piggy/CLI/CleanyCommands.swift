import Foundation
import ArgumentParser
import PiggyKit

nonisolated(unsafe) private var _cachedApps: [AppInfo]?

func piggyActivityGerund(_ raw: String) -> String {
    switch raw.lowercased() {
    case "snort", "snorting": return "snorting"
    case "search", "searching": return "searching"
    case "mudmap", "mud-map", "mud map", "stye", "map", "mapping": return "mapping"
    default: return "sniffing"
    }
}

func piggyActivityName(_ raw: String) -> String {
    switch raw.lowercased() {
    case "snort", "snorting": return "snort"
    case "search", "searching": return "search"
    case "mudmap", "mud-map", "mud map", "stye", "map", "mapping": return "mud map"
    default: return "sniff"
    }
}

func piggyActivityDoneLabel(_ raw: String) -> String {
    "Piggy \(piggyActivityName(raw)) is complete"
}

func scannedApps(useDiskCache: Bool = true, activity: String = "sniff") -> [AppInfo] {
    if let cached = _cachedApps { return cached }
    if useDiskCache, let cached = AppScanCache.loadIfFresh() {
        _cachedApps = cached
        return cached
    }

    var apps: [AppInfo] = []
    let indicator = TerminalActivityIndicator(action: "Piggy is \(piggyActivityGerund(activity)) through \"apps\"", doneLabel: piggyActivityDoneLabel(activity))
    indicator.start("Applications folders")
    apps = AppScanner.scan { current, total, name in
        let appName = TerminalActivityIndicator.clipped(name.replacingOccurrences(of: ".app", with: ""), to: 42)
        indicator.update("\(current)/\(total) · \(appName)")
    }
    indicator.finish("\(apps.count) apps")
    _cachedApps = apps
    AppScanCache.save(apps)
    return apps
}

// MARK: - snort

struct Snort: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Detailed look: piggy snort [what] [where]")

    @Argument(help: "What and where, e.g. apps, imgs ~/Pictures, docs ~/Documents")
    var words: [String] = []

    @Option(name: .shortAndLong, help: "Number of items to show")
    var limit: Int = 20

    @Flag(name: .long, help: "Force a fresh app scan when snorting apps")
    var fresh: Bool = false

    func run() throws {
        let plan = try PiggyCommandPlan.parse(action: .snort, words: words)
        try PiggyActionRunner.run(plan, limit: limit, fresh: fresh)
    }
}

// MARK: - list

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show the app pile Piggy found", shouldDisplay: false)

    @Option(name: .long, help: "Sort key: size, name, created, modified, used, arch, version, store, agents")
    var sort: String = "size"

    @Flag(name: .shortAndLong, help: "Sort in ascending order")
    var asc: Bool = false

    @Option(name: .shortAndLong, help: "Filter by name substring")
    var filter: String?

    @Flag(name: .long, help: "Show only Apple-signed apps")
    var appleOnly: Bool = false

    @Flag(name: .long, help: "Show only third-party apps")
    var thirdParty: Bool = false

    @Flag(name: .long, help: "Show only Rosetta (x86_64) apps")
    var rosetta: Bool = false

    @Flag(name: .long, help: "Show only 32-bit (dead) apps")
    var flag32bit: Bool = false

    @Flag(name: .long, help: "Show only quarantined (unverified) apps")
    var quarantined: Bool = false

    @Flag(name: .long, help: "Force a fresh app scan and update the cache")
    var fresh: Bool = false

    @Flag(name: .long, help: "Print machine-readable JSON instead of the compact table")
    var json: Bool = false

    @Option(name: .customLong("activity"), help: .hidden)
    var activity: String = "sniff"

    func run() throws {
        let apps = loadAndSort()
        if apps.isEmpty {
            if json {
                print("[]")
            } else {
                print("🐽 Piggy did not find any apps to show.")
            }
            return
        }
        if json {
            print(try AppReportRecord.encodeJSON(apps))
            return
        }
        printListIntro(apps)
        printTable(apps)
        printSummary(apps)
    }

    func loadAndSort() -> [AppInfo] {
        var apps = scannedApps(useDiskCache: !fresh, activity: activity)

        let sk = SortKey(argument: sort) ?? .size
        let ascending = asc
        apps.sort(by: SortKey.comparator(sk, ascending: ascending))

        if let filterStr = filter, !filterStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let matchedIDs = AppSearch.visibleNameMatchedAppIDs(apps, query: filterStr)
            apps = apps.filter { matchedIDs.contains($0.id) }
        }

        if appleOnly { apps = apps.filter { $0.isAppleSigned } }
        if thirdParty { apps = apps.filter { !$0.isAppleSigned } }
        if rosetta { apps = apps.filter { $0.architecture == .x86_64 } }
        if flag32bit { apps = apps.filter { $0.architecture == .i386 } }
        if quarantined { apps = apps.filter { $0.isQuarantined } }

        return apps
    }

    func printTable(_ apps: [AppInfo]) {
        let countW = 5
        let nameW = min(apps.map { $0.displayName.count }.max() ?? 20, 32)
        let sizeW = 10
        let flaggedW = 13
        let installedW = 10
        let scopeW = 11
        let bundledW = 10

        let header = "  \(formatPadding("#", countW))\(formatPadding("App", nameW))  \(formatPadding("File size", sizeW))  \(formatPadding("Flagged", flaggedW))  \(formatPadding("Installed", installedW))  \(formatPadding("Scope", scopeW))  \(formatPadding("Bundled", bundledW))"
        let sep = "  " + String(repeating: "─", count: header.count - 2)
        print(CLITheme.label(header))
        print(CLITheme.separator(sep))

        for (i, app) in apps.enumerated() {
            let num = CLITheme.rank("\(i + 1)".padding(toLength: countW, withPad: " ", startingAt: 0), index: i)
            let name = CLITheme.path(ellipsize(app.displayName, width: nameW).padding(toLength: nameW, withPad: " ", startingAt: 0))
            let size = CLITheme.size(app.formattedSize.padding(toLength: sizeW, withPad: " ", startingAt: 0), bytes: app.size)
            let flagged = styledFlagged(for: app, width: flaggedW)
            let installed = styledOrigin(app.originLabel.padding(toLength: installedW, withPad: " ", startingAt: 0), app: app)
            let scope = styledSource(app.sourceLabel.padding(toLength: scopeW, withPad: " ", startingAt: 0), app: app)
            let bundled = relativeLabel(app.creationDate, width: bundledW)

            print("  \(num)\(name)  \(size)  \(flagged)  \(installed)  \(scope)  \(bundled)")
        }
    }

    private func printListIntro(_ apps: [AppInfo]) {
        print("")
        print(CLITheme.title("🐽 Piggy found your app pile"))
        print(CLITheme.separator("──────────────────────────"))
        print("\(CLITheme.purple("•")) Just looking: nothing is moved, edited, or trashed.")
        print("\(CLITheme.purple("•")) Bigger apps float to the top unless you choose another sort.")
        print("\(CLITheme.purple("•")) Bundled is the app bundle file date; updates can make old apps look new.")
        print("\(CLITheme.purple("•")) Scope tells where it lives: System = macOS, System-wide = /Applications, User = ~/Applications.")
        print("\(CLITheme.purple("•")) Flagged explains why Piggy thinks an app may deserve attention.")
        print("\(CLITheme.purple("•")) Need location, version, chip, or description? Use \(CLITheme.command("piggy info <app>")) or \(CLITheme.command("piggy list --json")).")
        print("")
        print("\(CLITheme.label("Showing")) \(CLITheme.gold("\(apps.count)")) apps")
    }

    private func styledArch(for app: AppInfo, width: Int) -> String {
        let raw = (flagArch(for: app) + app.architecture.shortLabel).padding(toLength: width, withPad: " ", startingAt: 0)
        if app.architecture == .i386 { return CLITheme.danger(raw) }
        if app.architecture == .x86_64 || app.isQuarantined { return CLITheme.warning(raw) }
        if app.architecture == .arm64 { return CLITheme.green(raw) }
        return CLITheme.label(raw)
    }

    private func styledSource(_ source: String, app: AppInfo) -> String {
        switch app.sourceDir {
        case .system:
            return CLITheme.purple(source)
        case .rootApp:
            return app.isAppleSigned ? CLITheme.green(source) : CLITheme.blue(source)
        case .userApp:
            return CLITheme.gold(source)
        }
    }

    private func styledOrigin(_ origin: String, app: AppInfo) -> String {
        if app.isQuarantined { return CLITheme.warning(origin) }
        if app.isFromAppStore { return CLITheme.green(origin) }
        if app.isAppleSigned { return CLITheme.purple(origin) }
        return CLITheme.blue(origin)
    }

    private func styledFlagged(for app: AppInfo, width: Int) -> String {
        let raw = app.flagSummary.padding(toLength: width, withPad: " ", startingAt: 0)
        if app.architecture == .i386 { return CLITheme.danger(raw) }
        if app.architecture == .x86_64 || app.isQuarantined { return CLITheme.warning(raw) }
        return CLITheme.label(raw)
    }

    private func flagArch(for app: AppInfo) -> String {
        if app.architecture == .i386 { return "!" }
        if app.architecture == .x86_64 { return "R" }
        if app.isQuarantined { return "~" }
        return ""
    }

    private func formatPadding(_ s: String, _ w: Int) -> String {
        s.padding(toLength: w, withPad: " ", startingAt: 0)
    }

    private func ellipsize(_ text: String, width: Int) -> String {
        guard width > 1 else { return String(text.prefix(max(0, width))) }
        guard text.count > width else { return text }
        return String(text.prefix(width - 1)) + "…"
    }

    private func printSummary(_ apps: [AppInfo]) {
        let totalSize = apps.reduce(0) { $0 + $1.size }
        let appleCount = apps.filter { $0.isAppleSigned }.count
        let thirdCount = apps.filter { !$0.isAppleSigned }.count
        let rosettaCount = apps.filter { $0.architecture == .x86_64 }.count
        let deadCount = apps.filter { $0.architecture == .i386 }.count

        let totalStr: String = {
            let absSize = abs(totalSize)
            if absSize >= 1_073_741_824 { return String(format: "%.2f GB", Double(absSize) / 1_073_741_824) }
            return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        }()
        print("")
        print("\(CLITheme.gold("\(apps.count) apps")) \(CLITheme.dim("(\(totalStr))")) \(CLITheme.dim("|")) \(CLITheme.label("Apple-made:")) \(CLITheme.green("\(appleCount)")) \(CLITheme.dim("|")) \(CLITheme.label("Other:")) \(CLITheme.blue("\(thirdCount)")) \(CLITheme.dim("|")) \(CLITheme.label("Older Intel-style:")) \(CLITheme.warning("\(rosettaCount)")) \(CLITheme.dim("|")) \(CLITheme.label("Very old:")) \(CLITheme.danger("\(deadCount)"))")
        print("\(CLITheme.label("Tiny flags:")) \(CLITheme.danger("!")) = very old, \(CLITheme.warning("R")) = older Intel-style, \(CLITheme.warning("~")) = downloaded app to check")
    }
}

// MARK: - info

struct Info: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Ask Piggy to explain one app", shouldDisplay: false)

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Flag(name: .long, help: "Print machine-readable JSON instead of the human explanation")
    var json: Bool = false

    func run() throws {
        let apps = scannedApps()
        guard let info = findApp(in: apps) else {
            if json {
                print("{}")
            } else {
                print("🐽 Piggy could not sniff out an app named '\(app)'.")
            }
            throw ExitCode.failure
        }
        if json {
            print(try AppReportRecord.encodeJSONObject(info))
            return
        }
        printInfo(info)
    }

    private func findApp(in apps: [AppInfo]) -> AppInfo? {
        let lower = app.lowercased()
        if let match = apps.first(where: {
            $0.displayName.lowercased() == lower ||
            $0.bundleIdentifier?.lowercased() == lower
        }) { return match }
        if let partial = apps.first(where: {
            $0.displayName.lowercased().contains(lower) ||
            ($0.bundleIdentifier?.lowercased().contains(lower) ?? false)
        }) { return partial }
        return nil
    }

    private func printInfo(_ info: AppInfo) {
        print("")
        print("  \(CLITheme.title("🐽 Piggy notes for \(info.displayName)"))")
        print("  " + CLITheme.separator(String(repeating: "─", count: min(info.displayName.count + 10, 60))))
        print("  \(CLITheme.label("Where it lives:"))   \(CLITheme.path(info.path.path))")
        if let bid = info.bundleIdentifier { print("  \(CLITheme.label("Mac app ID:"))       \(bid)") }
        if let sv = info.shortVersion { print("  \(CLITheme.label("Version:"))          \(CLITheme.gold(sv))") }
        if let bv = info.bundleVersion { print("  \(CLITheme.label("Build:"))            \(bv)") }
        if let minOS = info.minOSVersion { print("  \(CLITheme.label("Needs macOS:"))      \(minOS) or newer") }
        print("  \(CLITheme.label("File size:"))       \(CLITheme.size(info.formattedSize, bytes: info.size))")
        print("  \(CLITheme.label("Chip type:"))        \(styledArchLabel(for: info))")
        print("  \(CLITheme.label("Installed by:"))     \(styledOriginLabel(for: info))")
        print("  \(CLITheme.label("Apple trust check:")) \(info.isAppleSigned ? CLITheme.green("passed") : CLITheme.warning("not Apple-signed"))")
        if info.isFromAppStore { print("  \(CLITheme.label("App Store:"))        \(CLITheme.green("yes"))") }
        if info.isQuarantined { print("  \(CLITheme.warning("Downloaded flag:"))   still attached, so be careful") }
        if let cd = info.creationDate { print("  \(CLITheme.label("Bundled:"))         \(relativeLabel(cd))") }
        if let md = info.modificationDate { print("  \(CLITheme.label("Updated:"))          \(relativeLabel(md))") }
        if let lud = info.lastUsedDate { print("  \(CLITheme.label("Last opened:"))      \(relativeLabel(lud))") }
        if info.agentCount > 0 { print("  \(CLITheme.warning("Background helpers:")) \(CLITheme.warning("\(info.agentCount)"))") }
        if let purpose = info.purpose { print("  \(CLITheme.label("What it is:"))        \(purpose)") }

        let related = findRelatedFilesWithActivity(for: info)
        if !related.isEmpty {
            print("")
            print("  \(CLITheme.section("Related app crumbs:"))")
            var relTotal: Int64 = 0
            for rf in related {
                let sz = formatBytes(rf.size)
                print("    \(CLITheme.gold("[\(rf.category)]")) \(CLITheme.path(rf.path.lastPathComponent))  \(CLITheme.size(sz, bytes: rf.size))")
                relTotal += rf.size
            }
            print("  \(CLITheme.label("Crumb pile:"))       \(CLITheme.gold(formatBytes(relTotal)))")
        }
        print("")
    }

    private func styledArchLabel(for app: AppInfo) -> String {
        if app.architecture == .i386 { return CLITheme.danger(app.architecture.label) }
        if app.architecture == .x86_64 || app.isQuarantined { return CLITheme.warning(app.architecture.label) }
        if app.architecture == .arm64 { return CLITheme.green(app.architecture.label) }
        return CLITheme.label(app.architecture.label)
    }

    private func styledOriginLabel(for app: AppInfo) -> String {
        if app.isQuarantined { return CLITheme.warning(app.originLabel) }
        if app.isFromAppStore { return CLITheme.green(app.originLabel) }
        if app.isAppleSigned { return CLITheme.purple(app.originLabel) }
        return CLITheme.blue(app.originLabel)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let absSize = abs(bytes)
        switch absSize {
        case 0..<1024: return "\(bytes) B"
        case 1024..<1_048_576: return String(format: "%.1f KB", Double(absSize) / 1024)
        case 1_048_576..<1_073_741_824: return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        default: return String(format: "%.2f GB", Double(absSize) / 1_073_741_824)
        }
    }
}

// MARK: - delete

struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Move an app to the Mac Trash after Piggy asks you", shouldDisplay: false)

    @Argument(help: "App name or Mac app ID")
    var app: String

    @Flag(name: .shortAndLong, help: "Skip the safety question")
    var force: Bool = false

    @Flag(name: .long, help: "Also move safe related app crumbs, like caches and settings, to Trash")
    var withRelated: Bool = false

    func run() throws {
        let apps = scannedApps()
        let lower = app.lowercased()
        guard let info = apps.first(where: {
            $0.displayName.lowercased() == lower ||
            $0.displayName.lowercased().contains(lower) ||
            $0.bundleIdentifier?.lowercased() == lower ||
            ($0.bundleIdentifier?.lowercased().contains(lower) ?? false)
        }) else {
            print("🐽 Piggy could not sniff out an app named '\(app)'.")
            throw ExitCode.failure
        }

        print("")
        print(CLITheme.title("🐽 Piggy can move this app to Trash"))
        print(CLITheme.separator("────────────────────────────────────"))
        print("\(CLITheme.purple("•")) App: \(CLITheme.path(info.displayName))")
        print("\(CLITheme.purple("•")) Space: \(CLITheme.size(info.formattedSize, bytes: info.size))")
        print("\(CLITheme.purple("•")) Piggy uses the normal Mac Trash, so this is not a shredder.")

        if !withRelated {
            let related = findRelatedFilesWithActivity(for: info)
            if !related.isEmpty {
                let relTotal = related.reduce(0) { $0 + $1.size }
                let relSizeStr = formatBytes(relTotal)
                print("\(CLITheme.purple("•")) Piggy also found \(CLITheme.gold("\(related.count)")) related app crumbs (\(CLITheme.gold(relSizeStr))).")
                print("  \(CLITheme.label("Tip:")) add \(CLITheme.command("--with-related")) if you want Piggy to include safe crumbs too.")
            }
        }

        if !force {
            print("")
            print("Move \(info.displayName) to Trash? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("🐽 No problem. Piggy did not move anything.")
                return
            }
        }

        let indicator = TerminalActivityIndicator(action: "Piggy is moving items to Trash", doneLabel: "Trash move complete")
        indicator.start(info.displayName)
        let result = AppRemover.delete(app: info, includeRelated: withRelated) { progress in
            indicator.update(progress.statusSummary)
        }
        indicator.finish()
        if result.didTrash {
            print("🐽 Moved to Trash: \(result.appName)")
            if withRelated && !result.trashedRelatedFiles.isEmpty {
                print("  + \(result.trashedRelatedFiles.count) safe related app crumbs")
            }
            if withRelated && !result.skippedRelatedFiles.isEmpty {
                print("  Piggy skipped \(result.skippedRelatedFiles.count) sensitive crumbs to be safe.")
            }
            print("Trash pile: \(formatBytes(result.totalFreed))")
        } else {
            print("🐽 Piggy could not move \(info.displayName) to Trash.")
            if let reason = result.failureReason {
                print("Reason from macOS: \(reason)")
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let absSize = abs(bytes)
        switch absSize {
        case 0..<1024: return "\(bytes) B"
        case 1024..<1_048_576: return String(format: "%.1f KB", Double(absSize) / 1024)
        case 1_048_576..<1_073_741_824: return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        default: return String(format: "%.2f GB", Double(absSize) / 1_073_741_824)
        }
    }
}

// MARK: - search

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find stuff: piggy search [what] <words> [where]")

    @Argument(help: "What to search and words to find, e.g. apps xcode, docs tax ~/Documents")
    var words: [String] = []

    @Option(name: .shortAndLong, help: "Number of items to show")
    var limit: Int = 20

    @Flag(name: .long, help: "Print machine-readable JSON instead of result cards for app search")
    var json: Bool = false

    func run() throws {
        do {
            let plan = try PiggyCommandPlan.parse(action: .search, words: words)
            try PiggyActionRunner.run(plan, limit: limit)
        } catch PiggyCommandPlanError.missingSearchQuery {
            print("🐽 Search for what? Try `piggy search docs tax ~/Documents`.")
            throw ExitCode.failure
        }
    }

    func runLegacyAppSearch() throws {
        let query = words.joined(separator: " ")
        let apps = scannedApps(activity: "search")
        let matches = AppSearch.search(apps, query: query)
        let results = matches.apps

        if results.isEmpty {
            if json {
                print("[]")
            } else {
                print("🐽 Piggy could not sniff out any apps matching '\(query)'.")
            }
            return
        }

        if json {
            print(try AppReportRecord.encodeJSON(results))
            return
        }

        printSearchResults(results, query: query, usedTechnicalFallback: matches.usedTechnicalFallback)
    }

    private func printSearchResults(_ results: [AppInfo], query: String, usedTechnicalFallback: Bool) {
        print("")
        let appWord = results.count == 1 ? "app" : "apps"
        print(CLITheme.title("🐽 Piggy found \(results.count) \(appWord) matching \"\(query)\""))
        print(CLITheme.separator("──────────────────────────"))
        if usedTechnicalFallback {
            print("\(CLITheme.purple("•")) Piggy did not find that in app names, so it checked hidden Mac IDs and descriptions.")
        }
        print("")

        for (index, app) in results.enumerated() {
            print("  \(CLITheme.rank("\(index + 1).", index: index)) \(highlightedDisplayName(app.displayName, query: query))")
            print("     \(CLITheme.label("File size:"))     \(CLITheme.size(app.formattedSize, bytes: app.size))        \(CLITheme.label("Installed by:")) \(styledOriginLabel(for: app))")
            let flagged = app.flagSummary
            if flagged != "-" {
                print("     \(CLITheme.warning("Flagged:"))      \(CLITheme.warning(flagged))")
            }
            if let modified = app.modificationDate {
                print("     \(CLITheme.label("Updated:"))       \(relativeLabel(modified))")
            }
            if let shortVersion = app.shortVersion {
                let build = app.bundleVersion.map { " (build \($0))" } ?? ""
                print("     \(CLITheme.label("Version:"))       \(CLITheme.gold(shortVersion + build))")
            }
            print("     \(CLITheme.label("Description:"))   \(app.purpose ?? "-")")
            print("     \(CLITheme.label("Location:"))      \(CLITheme.path(displayPath(app.path)))")
            print("     \(CLITheme.label("Scope:"))         \(scopeDescription(for: app))")
            print("     \(CLITheme.label("Chip:"))          \(styledArchLabel(for: app))")
            if let bundleID = app.bundleIdentifier {
                print("     \(CLITheme.label("Bundle ID:"))     \(bundleID)")
            }
            if let created = app.creationDate {
                print("     \(CLITheme.label("Bundled:"))       \(relativeLabel(created)) (app updates can make an old app look newly added)")
            }
            print("     \(CLITheme.label("Helpers:"))       \(app.agentCount > 0 ? CLITheme.warning("\(app.agentCount)") : "0")")
            if app.isQuarantined {
                print("     \(CLITheme.warning("Downloaded:"))    quarantine flag still attached")
            }
            if index < results.count - 1 { print("") }
        }
    }

    private func highlightedDisplayName(_ name: String, query: String) -> String {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return CLITheme.path(name) }

        var pieces: [String] = []
        var cursor = name.startIndex
        while cursor < name.endIndex,
              let match = name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: cursor..<name.endIndex) {
            if cursor < match.lowerBound {
                pieces.append(CLITheme.path(String(name[cursor..<match.lowerBound])))
            }
            pieces.append(CLITheme.bold(CLITheme.path(String(name[match]))))
            cursor = match.upperBound
        }
        if cursor < name.endIndex {
            pieces.append(CLITheme.path(String(name[cursor..<name.endIndex])))
        }
        return pieces.joined()
    }

    private func styledArchLabel(for app: AppInfo) -> String {
        if app.architecture == .i386 { return CLITheme.danger(app.architecture.label) }
        if app.architecture == .x86_64 || app.isQuarantined { return CLITheme.warning(app.architecture.label) }
        if app.architecture == .arm64 { return CLITheme.green(app.architecture.label) }
        return CLITheme.label(app.architecture.label)
    }

    private func styledOriginLabel(for app: AppInfo) -> String {
        if app.isQuarantined { return CLITheme.warning(app.originLabel) }
        if app.isFromAppStore { return CLITheme.green(app.originLabel) }
        if app.isAppleSigned { return CLITheme.purple(app.originLabel) }
        return CLITheme.blue(app.originLabel)
    }

    private func scopeDescription(for app: AppInfo) -> String {
        switch app.sourceDir {
        case .system:
            return "System macOS app (/System/Applications)"
        case .rootApp:
            return "System-wide app (/Applications)"
        case .userApp:
            return "User app (~/Applications)"
        }
    }
}

// MARK: - orphans

struct Orphans: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find leftover app crumbs from apps you may have removed")

    @Flag(name: .shortAndLong, help: "Move safe leftover crumbs to Trash after Piggy asks")
    var delete: Bool = false

    func run() throws {
        let apps = scannedApps()
        let installedIDs = Set(apps.compactMap { $0.bundleIdentifier })
        let indicator = TerminalActivityIndicator(action: "Piggy is sniffing through leftover app crumbs", doneLabel: "Crumb hunt complete")
        indicator.start("snout in your Library support folders")
        let orphans = OrphanScanner.scan(installedBundleIDs: installedIDs) { progress in
            let path = TerminalActivityIndicator.clipped(displayPath(progress.currentURL), to: 44)
            indicator.update("\(progress.statusSummary) · \(path)")
        }
        indicator.finish("\(orphans.count) crumb piles found")

        if orphans.isEmpty {
            print("🐽 Piggy did not find leftover app crumbs. Nice and tidy.")
            return
        }

        let totalSize = orphans.reduce(0) { $0 + $1.size }
        let totalStr = formatBytes(totalSize)

        let catW = 14
        let sizeW = 10
        print("")
        print(CLITheme.title("🐽 Leftover app crumbs Piggy found"))
        print(CLITheme.separator("──────────────────────────────────"))
        print("\(CLITheme.purple("•")) Just looking: Piggy will not move anything unless you add \(CLITheme.command("--delete")) and say yes.")
        print("\(CLITheme.purple("•")) Crumbs are settings, caches, logs, or support folders left behind by apps.")
        print("")
        print("  \(CLITheme.label("Kind".padding(toLength: catW, withPad: " ", startingAt: 0)))  \(CLITheme.label("Space".padding(toLength: sizeW, withPad: " ", startingAt: 0)))  \(CLITheme.label("Maybe from"))         \(CLITheme.label("Where Piggy found it"))")
        print("  " + CLITheme.separator(String(repeating: "─", count: min(catW + sizeW + 60, 100))))

        for orphan in orphans {
            let cat = CLITheme.gold(orphan.category.padding(toLength: catW, withPad: " ", startingAt: 0))
            let size = CLITheme.size(orphan.formattedSize.padding(toLength: sizeW, withPad: " ", startingAt: 0), bytes: orphan.size)
            let appName = (orphan.likelyAppName ?? "-").padding(toLength: 18, withPad: " ", startingAt: 0)
            let path = CLITheme.path(orphan.path.path)
            print("  \(cat)  \(size)  \(appName) \(path)")
        }

        print("")
        print("\(CLITheme.warning("\(orphans.count) crumb piles")) \(CLITheme.dim("(\(totalStr))")) Piggy can help review")

        if self.delete {
            print("Move safe leftover crumbs to Trash? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("🐽 No problem. Piggy did not move anything.")
                return
            }
            let relatedFiles = orphans.map { AppRemover.RelatedFile(path: $0.path, size: $0.size, category: $0.category) }
            let deleteIndicator = TerminalActivityIndicator(action: "Piggy is moving crumbs to Trash", doneLabel: "Crumb move complete")
            deleteIndicator.start("\(relatedFiles.count) crumb piles")
            let result = AppRemover.deleteRelatedFiles(relatedFiles) { progress in
                deleteIndicator.update(progress.statusSummary)
            }
            deleteIndicator.finish("\(result.trashed.count) moved")
            print("🐽 Moved \(result.trashed.count) crumb piles to Trash. Trash pile: \(formatBytes(result.totalFreed))")
            if !result.skipped.isEmpty {
                print("Piggy skipped \(result.skipped.count) sensitive crumbs to be safe.")
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let absSize = abs(bytes)
        switch absSize {
        case 0..<1024: return "\(bytes) B"
        case 1024..<1_048_576: return String(format: "%.1f KB", Double(absSize) / 1024)
        case 1_048_576..<1_073_741_824: return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        default: return String(format: "%.2f GB", Double(absSize) / 1_073_741_824)
        }
    }
}

// MARK: - export

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Let Piggy pack the app list into CSV or JSON", shouldDisplay: false)

    @Option(name: .shortAndLong, help: "Output format: csv or json")
    var format: String = "csv"

    @Option(name: .long, help: "Output file path (default: stdout)")
    var output: String?

    func run() throws {
        var apps = scannedApps()
        apps.sort { $0.size > $1.size }

        let outputStr: String
        switch format.lowercased() {
        case "json":
            outputStr = try AppReportRecord.encodeJSON(apps)
        default:
            var lines = ["Name,Size,Bundle ID,Arch,Source,Origin,Version,Agents,Quarantined,Purpose,Path"]
            for app in apps {
                let fields = [
                    csvEscape(app.displayName),
                    app.formattedSize,
                    csvEscape(app.bundleIdentifier ?? ""),
                    app.architecture.shortLabel,
                    app.sourceLabel,
                    app.originLabel,
                    csvEscape(app.shortVersion ?? ""),
                    "\(app.agentCount)",
                    app.isQuarantined ? "yes" : "no",
                    csvEscape(app.purpose ?? ""),
                    csvEscape(app.path.path),
                ]
                lines.append(fields.joined(separator: ","))
            }
            outputStr = lines.joined(separator: "\n") + "\n"
        }

        if let path = output {
            try outputStr.write(toFile: path, atomically: true, encoding: .utf8)
            print("🐽 Piggy packed the app list here: \(path)")
        } else {
            print(outputStr, terminator: "")
        }
    }

    private func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }
}

private func findRelatedFilesWithActivity(for app: AppInfo) -> [AppRemover.RelatedFile] {
    let indicator = TerminalActivityIndicator(action: "Piggy is sniffing through \(app.displayName)'s app crumbs", doneLabel: "Related crumb hunt complete")
    indicator.start(app.displayName)
    let related = AppRemover.findRelatedFiles(for: app) { progress in
        indicator.update(progress.statusSummary)
    }
    indicator.finish("\(related.count) related")
    return related
}

private func displayPath(_ url: URL) -> String {
    let path = url.standardizedFileURL.path
    let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

private func relativeLabel(_ date: Date) -> String {
    let interval = -date.timeIntervalSinceNow
    if interval < 60 { return "just now" }
    if interval < 3600 { return "\(Int(interval / 60))m ago" }
    if interval < 86400 { return "\(Int(interval / 3600))h ago" }
    if interval < 2592000 { return "\(Int(interval / 86400))d ago" }
    if interval < 31536000 { return "\(Int(interval / 2592000))m ago" }
    return "\(Int(interval / 31536000))y ago"
}

private func relativeLabel(_ date: Date?, width: Int) -> String {
    guard let date else { return "-".padding(toLength: width, withPad: " ", startingAt: 0) }
    let raw = relativeLabel(date)
    return raw.padding(toLength: width, withPad: " ", startingAt: 0)
}
