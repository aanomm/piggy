import Foundation
import ArgumentParser
import PiggyKit

struct Folders: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "folders",
        abstract: "Find the biggest folders under a path, with file counts",
        discussion: "Non-destructive folder audit. By default Piggy ranks immediate child folders and skips hidden files/folders. Use --depth for nested folder findings."
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

    func run() throws {
        let rootURL = URL(fileURLWithPath: selectedRootPath()).standardizedFileURL
        guard isDirectory(rootURL) else {
            print("Piggy could not find that folder: \(rootURL.path)")
            throw ExitCode.failure
        }

        let minimumBytes: Int64
        if let minSize {
            do {
                minimumBytes = try ByteSizeParser.parse(minSize)
            } catch {
                print("Piggy could not understand --min-size '\(minSize)'. Try values like 500mb or 2gb.")
                throw ExitCode.failure
            }
        } else {
            minimumBytes = 0
        }

        printHeader(rootURL: rootURL, minimumBytes: minimumBytes)

        let findings = FolderScanner.scan(
            root: rootURL,
            maxDepth: depth,
            includeHidden: includeHidden,
            minimumBytes: minimumBytes
        )
        let shown = Array(findings.prefix(max(0, limit)))

        guard !shown.isEmpty else {
            print("No matching folders found. Tiny truffle field. 🐽")
            print("")
            return
        }

        printTable(shown, rootURL: rootURL)
        printFooter(allFindings: findings, shownCount: shown.count)
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
        print("🐷 Piggy Folder Audit")
        print("─────────────────────")
        print("Scope: non-destructive scan of folders under \(displayRoot(rootURL))")
        print("Disk:  Combined size of each folder's visible contents.")
        print("Files: Regular files counted recursively inside each folder.")
        if depth > 1 {
            print("Note:  Nested rows may overlap when --depth is greater than 1.")
        }
        if minimumBytes > 0 {
            print("Filter: folders at least \(ByteFormat.string(minimumBytes))")
        }
        if includeHidden {
            print("Hidden: included")
        }
        print("")
    }

    private func printTable(_ folders: [FolderFinding], rootURL: URL) {
        let numberWidth = max(2, String(folders.count).count + 1)
        let sizeWidth = 11
        let filesWidth = 7
        let nestedWidth = 7

        let header = "\(pad("#", numberWidth))  \(pad("Size", sizeWidth))  \(pad("Files", filesWidth))  \(pad("Folders", nestedWidth))  Folder"
        print(header)
        print(String(repeating: "─", count: header.count))

        for (index, folder) in folders.enumerated() {
            let number = pad("\(index + 1).", numberWidth)
            let size = pad(folder.formattedSize, sizeWidth)
            let files = pad("\(folder.fileCount)", filesWidth)
            let nested = pad("\(folder.nestedFolderCount)", nestedWidth)
            print("\(number)  \(size)  \(files)  \(nested)  \(displayPath(folder.url, rootURL: rootURL))")
        }
    }

    private func printFooter(allFindings: [FolderFinding], shownCount: Int) {
        let totalBytes = allFindings.reduce(Int64(0)) { $0 + $1.totalBytes }
        let totalFiles = allFindings.reduce(0) { $0 + $1.fileCount }
        print("")
        print("Folders scanned \(allFindings.count) | shown \(shownCount) | files counted \(totalFiles) | folder disk \(ByteFormat.string(totalBytes))")
        print("Safe next commands:")
        print("  piggy folders ~/Downloads --limit 25")
        print("  piggy folders ~/Library --min-size 1gb")
        print("  piggy mac audit")
        print("")
    }

    private func displayRoot(_ url: URL) -> String {
        displayPath(url, rootURL: nil)
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
}

struct Folder: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "folder",
        abstract: "Alias for `piggy folders`"
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
        if let minSize { args.append(contentsOf: ["--min-size", minSize]) }
        if includeHidden { args.append("--include-hidden") }
        return args
    }
}
