import Foundation
import ArgumentParser

nonisolated(unsafe) private var _cachedApps: [AppInfo]?

private func scannedApps(useDiskCache: Bool = true) -> [AppInfo] {
    if let cached = _cachedApps { return cached }
    if useDiskCache, let cached = AppScanCache.loadIfFresh() {
        _cachedApps = cached
        return cached
    }

    var apps: [AppInfo] = []
    Spinner.runDuringScan { progress in
        apps = AppScanner.scan(progress: progress)
    }
    _cachedApps = apps
    AppScanCache.save(apps)
    return apps
}

// MARK: - snort

struct Snort: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List installed applications by size or install date")

    enum Order: String, ExpressibleByArgument {
        case big
        case small
        case new
        case old
    }

    @Argument(help: "Order: big for largest first, small for smallest first, new for newest installed, old for oldest installed")
    var order: Order = .big

    @Flag(name: .long, help: "Force a fresh app scan and update the cache")
    var fresh: Bool = false

    func run() throws {
        var args: [String]
        switch order {
        case .big:
            args = ["--sort", "size"]
        case .small:
            args = ["--sort", "size", "--asc"]
        case .new:
            args = ["--sort", "created"]
        case .old:
            args = ["--sort", "created", "--asc"]
        }
        if fresh { args.append("--fresh") }
        let list = List.parseOrExit(args)
        try list.run()
    }
}

// MARK: - list

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List all installed applications")

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

    func run() throws {
        let apps = loadAndSort()
        if apps.isEmpty {
            print("No apps found.")
            return
        }
        printTable(apps)
        printSummary(apps)
    }

    func loadAndSort() -> [AppInfo] {
        var apps = scannedApps(useDiskCache: !fresh)

        let sk = SortKey(rawValue: sort) ?? .size
        let ascending = asc
        apps.sort(by: SortKey.comparator(sk, ascending: ascending))

        if let filterStr = filter?.lowercased(), !filterStr.isEmpty {
            apps = apps.filter {
                $0.displayName.lowercased().contains(filterStr) ||
                ($0.bundleIdentifier?.lowercased().contains(filterStr) ?? false) ||
                ($0.purpose?.lowercased().contains(filterStr) ?? false)
            }
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
        let nameW = min(apps.map { $0.displayName.count }.max() ?? 20, 30)
        let sizeW = 10
        let dateW = 10
        let archW = 7
        let sourceW = 11
        let originW = 10
        let verW = 12

        let header = "  \(formatPadding("#", countW))\(formatPadding("Name", nameW))  \(formatPadding("Size", sizeW))  \(formatPadding("Installed", dateW))  \(formatPadding("Arch", archW))  \(formatPadding("Source", sourceW))  \(formatPadding("Origin", originW))  \(formatPadding("Version", verW))  Agents  Purpose"
        let sep = "  " + String(repeating: "─", count: header.count - 2)
        print(header)
        print(sep)

        for (i, app) in apps.enumerated() {
            let num = "\(i + 1)".padding(toLength: countW, withPad: " ", startingAt: 0)
            let name = String(app.displayName.prefix(nameW)).padding(toLength: nameW, withPad: " ", startingAt: 0)
            let size = app.formattedSize.padding(toLength: sizeW, withPad: " ", startingAt: 0)
            let date = relativeLabel(app.creationDate, width: dateW)
            let arch = (flagArch(for: app) + app.architecture.shortLabel).padding(toLength: archW, withPad: " ", startingAt: 0)
            let source = app.sourceLabel.padding(toLength: sourceW, withPad: " ", startingAt: 0)
            let origin = app.originLabel.padding(toLength: originW, withPad: " ", startingAt: 0)
            let version = (app.shortVersion ?? "-").prefix(12).padding(toLength: verW, withPad: " ", startingAt: 0)
            let agents = "\(app.agentCount)".padding(toLength: 6, withPad: " ", startingAt: 0)
            let purpose = (app.purpose ?? "-").prefix(35)

            print("  \(num)\(name)  \(size)  \(date)  \(arch)  \(source)  \(origin)  \(version)  \(agents)\(purpose)")
        }
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
        print("\(apps.count) apps (\(totalStr)) | Apple: \(appleCount) | 3rd Party: \(thirdCount) | Rosetta: \(rosettaCount) | 32-bit: \(deadCount)")
        print("Legend: ! = 32-bit, R = Rosetta/x86_64, ~ = quarantined")
    }
}

// MARK: - info

struct Info: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show detailed info for an app")

    @Argument(help: "App name or bundle identifier")
    var app: String

    func run() throws {
        let apps = scannedApps()
        guard let info = findApp(in: apps) else {
            print("App not found: \(app)")
            throw ExitCode.failure
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
        print("  \(info.displayName)")
        print("  " + String(repeating: "─", count: min(info.displayName.count + 10, 60)))
        print("  Path:             \(info.path.path)")
        if let bid = info.bundleIdentifier { print("  Bundle ID:        \(bid)") }
        if let sv = info.shortVersion { print("  Version:          \(sv)") }
        if let bv = info.bundleVersion { print("  Build:            \(bv)") }
        if let minOS = info.minOSVersion { print("  Min macOS:        \(minOS)") }
        print("  Size:             \(info.formattedSize)")
        print("  Architecture:     \(info.architecture.label)")
        print("  Origin:           \(info.originLabel)")
        print("  Code Signed:      Apple: \(info.isAppleSigned ? "yes" : "no")")
        if info.isFromAppStore { print("  App Store:        yes") }
        if info.isQuarantined { print("  Quarantined:      yes (unverified)") }
        if let cd = info.creationDate { print("  Installed:        \(relativeLabel(cd))") }
        if let md = info.modificationDate { print("  Modified:         \(relativeLabel(md))") }
        if let lud = info.lastUsedDate { print("  Last Used:        \(relativeLabel(lud))") }
        if info.agentCount > 0 { print("  Background Agents: \(info.agentCount)") }
        if let purpose = info.purpose { print("  Purpose:          \(purpose)") }

        let related = AppRemover.findRelatedFiles(for: info)
        if !related.isEmpty {
            print("")
            print("  Related files:")
            var relTotal: Int64 = 0
            for rf in related {
                let sz = formatBytes(rf.size)
                print("    [\(rf.category)] \(rf.path.lastPathComponent)  \(sz)")
                relTotal += rf.size
            }
            print("  Total related:    \(formatBytes(relTotal))")
        }
        print("")
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
    static let configuration = CommandConfiguration(abstract: "Delete an app and optionally its related files")

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force: Bool = false

    @Flag(name: .long, help: "Also delete related files (prefs, caches, containers)")
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
            print("App not found: \(app)")
            throw ExitCode.failure
        }

        print("Deleting: \(info.displayName) (\(info.formattedSize))")

        if !withRelated {
            let related = AppRemover.findRelatedFiles(for: info)
            if !related.isEmpty {
                let relTotal = related.reduce(0) { $0 + $1.size }
                let relSizeStr = formatBytes(relTotal)
                print("  Also found \(related.count) related files (\(relSizeStr)). Use --with-related to clean those too.")
            }
        }

        if !force {
            print("Are you sure? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
        }

        let result = AppRemover.delete(app: info, includeRelated: withRelated)
        if result.didTrash {
            print("Trashed: \(result.appName)")
            if withRelated && !result.relatedFiles.isEmpty {
                print("  + \(result.relatedFiles.count) related files")
            }
            print("Freed: \(formatBytes(result.totalFreed))")
        } else {
            print("Failed to trash: \(info.displayName)")
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
    static let configuration = CommandConfiguration(abstract: "Search apps by name, bundle ID, or purpose")

    @Argument(help: "Search query")
    var query: String

    func run() throws {
        let apps = scannedApps()
        let lower = query.lowercased()
        let results = apps.filter {
            $0.displayName.lowercased().contains(lower) ||
            ($0.bundleIdentifier?.lowercased().contains(lower) ?? false) ||
            ($0.purpose?.lowercased().contains(lower) ?? false)
        }.sorted { $0.size > $1.size }

        if results.isEmpty {
            print("No apps matching '\(query)'")
            return
        }

        List().printTable(results)
    }
}

// MARK: - orphans

struct Orphans: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find leftover files from deleted apps")

    @Flag(name: .shortAndLong, help: "Delete all orphan files with confirmation")
    var delete: Bool = false

    func run() throws {
        let apps = scannedApps()
        let installedIDs = Set(apps.compactMap { $0.bundleIdentifier })
        let orphans = OrphanScanner.scan(installedBundleIDs: installedIDs)

        if orphans.isEmpty {
            print("No orphans found. Clean!")
            return
        }

        let totalSize = orphans.reduce(0) { $0 + $1.size }
        let totalStr = formatBytes(totalSize)

        let catW = 14
        let sizeW = 10
        print("")
        print("  \("Category".padding(toLength: catW, withPad: " ", startingAt: 0))  \("Size".padding(toLength: sizeW, withPad: " ", startingAt: 0))  Likely App          Path")
        print("  " + String(repeating: "─", count: min(catW + sizeW + 60, 100)))

        for orphan in orphans {
            let cat = orphan.category.padding(toLength: catW, withPad: " ", startingAt: 0)
            let size = orphan.formattedSize.padding(toLength: sizeW, withPad: " ", startingAt: 0)
            let appName = (orphan.likelyAppName ?? "-").padding(toLength: 18, withPad: " ", startingAt: 0)
            let path = orphan.path.path
            print("  \(cat)  \(size)  \(appName) \(path)")
        }

        print("")
        print("\(orphans.count) orphans (\(totalStr)) reclaimable")

        if self.delete {
            print("Delete all \(orphans.count) orphans? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
            let relatedFiles = orphans.map { AppRemover.RelatedFile(path: $0.path, size: $0.size, category: $0.category) }
            AppRemover.deleteRelatedFiles(relatedFiles)
            print("Deleted all orphans. Freed: \(totalStr)")
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
    static let configuration = CommandConfiguration(abstract: "Export app list to CSV or JSON")

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
            var jsonArray: [[String: Any]] = []
            for app in apps {
                var dict: [String: Any] = [
                    "name": app.displayName,
                    "bundle_id": app.bundleIdentifier ?? "",
                    "path": app.path.path,
                    "size_bytes": app.size,
                    "size_formatted": app.formattedSize,
                    "architecture": app.architecture.shortLabel,
                    "source": app.sourceLabel,
                    "origin": app.originLabel,
                    "apple_signed": app.isAppleSigned,
                    "app_store": app.isFromAppStore,
                    "quarantined": app.isQuarantined,
                    "agents": app.agentCount,
                ]
                if let sv = app.shortVersion { dict["version"] = sv }
                if let purpose = app.purpose { dict["purpose"] = purpose }
                jsonArray.append(dict)
            }
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys])
            outputStr = String(data: data, encoding: .utf8) ?? "{}"
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
            print("Exported to \(path)")
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
