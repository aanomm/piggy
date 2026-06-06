import Foundation
import ArgumentParser
import PiggyKit

struct Folders: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "folders",
        abstract: "Show which folders are taking up the most space.",
        discussion: "Piggy looks inside one folder, weighs the folders inside it, and shows the biggest ones first. Piggy does not change anything.",
        shouldDisplay: false
    )

    @Argument(help: "Root folder to inspect. Defaults to the current directory.")
    var root: String = "."

    @Option(name: .long, help: "Root folder to inspect. Overrides the positional path.")
    var path: String?

    @Option(name: .shortAndLong, help: "Number of folders to show.")
    var limit: Int = 20

    @Option(name: .long, help: "How many folder levels to rank as separate findings.")
    var depth: Int = 1

    @Option(name: .long, help: "Only show folders at least this size, e.g. 500mb, 2gb.")
    var minSize: String?

    @Flag(name: .long, help: "Include hidden dotfiles and dotfolders.")
    var includeHidden: Bool = false

    @Option(name: .customLong("activity"), help: .hidden)
    var activity: String = "sniff"

    func run() throws {
        let rootURL = URL(fileURLWithPath: selectedRootPath()).standardizedFileURL
        guard isDirectory(rootURL) else {
            print("🐽 Piggy could not find that folder: \(rootURL.path)")
            throw ExitCode.failure
        }

        let minimumBytes: Int64
        if let minSize {
            do {
                minimumBytes = try ByteSizeParser.parse(minSize)
            } catch {
                print("🐽 Piggy could not understand --min-size '\(minSize)'. Try a simple size like 500mb or 2gb.")
                throw ExitCode.failure
            }
        } else {
            minimumBytes = 0
        }

        printHeader(rootURL: rootURL, minimumBytes: minimumBytes)

        let indicator = TerminalActivityIndicator(action: "Piggy is \(piggyActivityGerund(activity)) through \"\(friendlyRootName(rootURL))\"", doneLabel: piggyActivityDoneLabel(activity))
        indicator.start(displayRoot(rootURL))
        let result = FolderScanner.scanWithSummary(
            root: rootURL,
            maxDepth: depth,
            includeHidden: includeHidden,
            minimumBytes: minimumBytes,
            progress: { progress in
                let path = TerminalActivityIndicator.clipped(
                    displayPath(progress.currentURL, rootURL: rootURL),
                    to: 54
                )
                indicator.update("\(progress.statusSummary)  ·  \(path)")
            }
        )
        indicator.finish(result.summary.statusSummary)
        let findings = result.findings
        let shown = Array(findings.prefix(max(0, limit)))

        guard !shown.isEmpty else {
            print("🐽 Piggy did not find any folders big enough to show.")
            print("")
            return
        }

        printTable(shown, rootURL: rootURL, scanTotalBytes: result.summary.totalBytes)
        printFooter(summary: result.summary, rankedCount: findings.count, shownCount: shown.count)
    }

    private func selectedRootPath() -> String {
        let rawPath = path ?? root
        return (rawPath as NSString).expandingTildeInPath
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func printHeader(rootURL: URL, minimumBytes: Int64) {
        print("")
        print("\(CLITheme.title("🐽 Oink! Piggy is \(piggyActivityGerund(activity)) through \"\(friendlyRootName(rootURL))\""))")
        print(CLITheme.separator("─────────────────────"))
        print("\(CLITheme.purple("•")) Looking inside: \(CLITheme.path(displayRoot(rootURL)))")
        print("\(CLITheme.purple("•")) Full path: \(CLITheme.dim(rootURL.path))")
        print("\(CLITheme.purple("•")) Just looking: Piggy will not eat, delete, or edit anything.")
        print("\(CLITheme.purple("•")) Ranking folders by how much space their contents use.")
        print("\(CLITheme.purple("•")) Hidden Mac files stay tucked away unless you ask for them.")
        if depth > 1 {
            print("\(CLITheme.purple("•")) Peeking deeper: nested rows can overlap; scan total counts each file once.")
        }
        if minimumBytes > 0 {
            print("\(CLITheme.purple("•")) Only showing folders at least \(CLITheme.gold(ByteFormat.string(minimumBytes))).")
        }
        if includeHidden {
            print("\(CLITheme.purple("•")) Hidden Mac files are included this time.")
        }
        print("")
    }

    private func printTable(_ folders: [FolderFinding], rootURL: URL, scanTotalBytes: Int64) {
        let numberWidth = max(2, String(folders.count).count + 1)
        let shareWidth = 7
        let barWidth = max(12, min(30, Banner.currentTerminalWidth() / 4))
        let sizeWidth = 11
        let filesWidth = 7
        let nestedWidth = 7
        let maxBytes = folders.map(\.totalBytes).max() ?? 0

        print(CLITheme.title("Biggest folder snacks"))

        let header = "\(pad("#", numberWidth))  \(pad("Of scan", shareWidth))  \(pad("Size bar", barWidth))  \(pad("Space", sizeWidth))  \(pad("Files", filesWidth))  \(pad("Folders", nestedWidth))  Folder"
        print(CLITheme.label(header))
        print(CLITheme.separator(String(repeating: "─", count: header.count)))

        for (index, folder) in folders.enumerated() {
            let number = CLITheme.rank(pad("\(index + 1).", numberWidth), index: index)
            let share = scanTotalBytes > 0 ? Double(folder.totalBytes) / Double(scanTotalBytes) : 0
            let shareText = CLITheme.rank(pad(String(format: "%.1f%%", share * 100), shareWidth), index: index)
            let bar = CLITheme.bar(value: folder.totalBytes, max: maxBytes, width: barWidth, index: index)
            let size = CLITheme.size(pad(folder.formattedSize, sizeWidth), bytes: folder.totalBytes)
            let files = pad("\(folder.fileCount)", filesWidth)
            let nested = pad("\(folder.nestedFolderCount)", nestedWidth)
            let path = CLITheme.path(displayPath(folder.url, rootURL: rootURL))
            print("\(number)  \(shareText)  \(bar)  \(size)  \(files)  \(nested)  \(path)")
        }
    }

    private func printFooter(summary: FolderScanSummary, rankedCount: Int, shownCount: Int) {
        print("")
        print("\(CLITheme.label("Piggy \(piggyActivityName(activity)) summary")) \(CLITheme.dim("|")) \(CLITheme.label("scanned")) \(countLabel(summary.foldersVisited, "folder")) \(CLITheme.dim("|")) \(CLITheme.label("counted")) \(countLabel(summary.filesCounted, "file")) \(CLITheme.dim("|")) \(CLITheme.label("scan total")) \(CLITheme.gold(ByteFormat.string(summary.totalBytes))) \(CLITheme.dim("|")) \(CLITheme.label("ranked")) \(rankedCount) \(CLITheme.dim("|")) \(CLITheme.label("showed")) \(shownCount)")
        print(CLITheme.section("Try next:"))
        print("  \(CLITheme.command("piggy sniff ~/Downloads"))")
        print("  \(CLITheme.command("piggy snort ~/Library"))")
        print("  \(CLITheme.command("piggy mudmap ~/Downloads"))")
        print("")
    }

    private func displayRoot(_ url: URL) -> String {
        displayPath(url, rootURL: nil)
    }

    private func friendlyRootName(_ url: URL) -> String {
        let name = url.lastPathComponent
        if name.isEmpty {
            return url.path
        }
        if url.standardizedFileURL.path == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path {
            return "Home"
        }
        return name
    }

    private func displayPath(_ url: URL, rootURL: URL?) -> String {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        if let rootURL {
            let rootPath = rootURL.standardizedFileURL.path
            if path.hasPrefix(rootPath + "/") {
                return String(path.dropFirst(rootPath.count + 1))
            }
        }
        return path
    }

    private func pad(_ value: String, _ width: Int) -> String {
        value.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    private func countLabel(_ count: Int, _ singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

struct Folder: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "folder",
        abstract: "Alias for `piggy folders`",
        shouldDisplay: false
    )

    @Argument(help: "Root folder to inspect. Defaults to the current directory.")
    var root: String = "."

    @Option(name: .long, help: "Root folder to inspect. Overrides the positional path.")
    var path: String?

    @Option(name: .shortAndLong, help: "Number of folders to show.")
    var limit: Int = 20

    @Option(name: .long, help: "How many folder levels to rank as separate findings.")
    var depth: Int = 1

    @Option(name: .long, help: "Only show folders at least this size, e.g. 500mb, 2gb.")
    var minSize: String?

    @Flag(name: .long, help: "Include hidden dotfiles and dotfolders.")
    var includeHidden: Bool = false

    @Option(name: .customLong("activity"), help: .hidden)
    var activity: String = "sniff"

    func run() throws {
        let args = translatedArgs()
        let command = Folders.parseOrExit(args)
        try command.run()
    }

    private func translatedArgs() -> [String] {
        var args: [String] = [root]
        if let path { args.append(contentsOf: ["--path", path]) }
        args.append(contentsOf: ["--limit", "\(limit)"])
        args.append(contentsOf: ["--depth", "\(depth)"])
        args.append(contentsOf: ["--activity", activity])
        if let minSize { args.append(contentsOf: ["--min-size", minSize]) }
        if includeHidden { args.append("--include-hidden") }
        return args
    }
}
