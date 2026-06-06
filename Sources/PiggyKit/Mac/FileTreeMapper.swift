import Foundation

public struct FileTreeMap: Equatable {
    public let root: FileTreeNode
    public let summary: FileTreeMapSummary
}

public struct FileTreeMapSummary: Equatable {
    public let foldersVisited: Int
    public let filesMapped: Int
    public let totalBytes: Int64

    public var statusSummary: String {
        "\(countLabel(foldersVisited, "folder")) · \(countLabel(filesMapped, "file")) · \(ByteFormat.string(totalBytes))"
    }

    private func countLabel(_ count: Int, _ singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

public struct FileTreeChildSummary: Equatable {
    public let folderCount: Int
    public let folderBytes: Int64
    public let fileCount: Int
    public let fileBytes: Int64

    public var totalBytes: Int64 { folderBytes + fileBytes }
    public var isEmpty: Bool { folderCount == 0 && fileCount == 0 }

    public var inlineOverview: String? {
        var parts: [String] = []
        if folderCount > 0 {
            parts.append("\(countLabel(folderCount, "folder")) \(ByteFormat.string(folderBytes))")
        }
        if fileCount > 0 {
            parts.append("\(countLabel(fileCount, "file")) \(ByteFormat.string(fileBytes))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func countLabel(_ count: Int, _ singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

public struct FileTreeNode: Equatable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let bytes: Int64
    public let children: [FileTreeNode]
    public let hiddenChildCount: Int
    public let isDepthLimited: Bool
    public let childSummary: FileTreeChildSummary?

    public init(
        name: String,
        url: URL,
        isDirectory: Bool,
        bytes: Int64,
        children: [FileTreeNode],
        hiddenChildCount: Int,
        isDepthLimited: Bool,
        childSummary: FileTreeChildSummary? = nil
    ) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.bytes = bytes
        self.children = children
        self.hiddenChildCount = hiddenChildCount
        self.isDepthLimited = isDepthLimited
        self.childSummary = childSummary
    }

    public var formattedSize: String { ByteFormat.string(bytes) }

    public var inlineLimitNote: String? {
        var parts: [String] = []
        if hiddenChildCount > 0 {
            parts.append("… \(hiddenChildCount) more")
        }
        if isDepthLimited {
            parts.append("… deeper folders hidden by --depth")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }
}

public enum FileTreeMapper {
    public static let defaultMaxDepth = 1

    public static func map(
        root: URL,
        maxDepth: Int = defaultMaxDepth,
        entriesPerFolder: Int = 30,
        includeHidden: Bool = false
    ) -> FileTreeMap {
        let normalizedRoot = root.standardizedFileURL
        var summary = BuilderSummary()
        let rootNode = buildNode(
            normalizedRoot,
            depth: 0,
            maxDepth: max(0, maxDepth),
            entriesPerFolder: max(1, entriesPerFolder),
            includeHidden: includeHidden,
            summary: &summary
        )
        return FileTreeMap(
            root: rootNode,
            summary: FileTreeMapSummary(
                foldersVisited: summary.foldersVisited,
                filesMapped: summary.filesMapped,
                totalBytes: rootNode.bytes
            )
        )
    }

    private static func buildNode(
        _ url: URL,
        depth: Int,
        maxDepth: Int,
        entriesPerFolder: Int,
        includeHidden: Bool,
        summary: inout BuilderSummary
    ) -> FileTreeNode {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .nameKey,
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory == true
        let name = values?.name ?? url.lastPathComponent

        if values?.isSymbolicLink == true {
            return FileTreeNode(
                name: name,
                url: url,
                isDirectory: isDirectory,
                bytes: 0,
                children: [],
                hiddenChildCount: 0,
                isDepthLimited: false
            )
        }

        guard isDirectory else {
            summary.filesMapped += 1
            return FileTreeNode(
                name: name,
                url: url,
                isDirectory: false,
                bytes: Int64(values?.fileSize ?? 0),
                children: [],
                hiddenChildCount: 0,
                isDepthLimited: false
            )
        }

        summary.foldersVisited += 1

        guard depth < maxDepth else {
            let stats = directoryStats(url, includeHidden: includeHidden)
            summary.foldersVisited += stats.folderCount
            summary.filesMapped += stats.fileCount
            let childSummary = visibleChildSummary(of: url, includeHidden: includeHidden)
            return FileTreeNode(
                name: name,
                url: url,
                isDirectory: true,
                bytes: stats.bytes,
                children: [],
                hiddenChildCount: 0,
                isDepthLimited: true,
                childSummary: childSummary
            )
        }

        let childURLs = visibleChildren(of: url, includeHidden: includeHidden)
        let nodes = childURLs.map {
            buildNode(
                $0,
                depth: depth + 1,
                maxDepth: maxDepth,
                entriesPerFolder: entriesPerFolder,
                includeHidden: includeHidden,
                summary: &summary
            )
        }
        let sorted = nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        let shown = Array(sorted.prefix(entriesPerFolder))
        let hiddenCount = max(0, sorted.count - shown.count)
        let totalBytes = sorted.reduce(Int64(0)) { $0 + $1.bytes }

        return FileTreeNode(
            name: name,
            url: url,
            isDirectory: true,
            bytes: totalBytes,
            children: shown,
            hiddenChildCount: hiddenCount,
            isDepthLimited: false
        )
    }

    private static func visibleChildren(of url: URL, includeHidden: Bool) -> [URL] {
        let keys: [URLResourceKey] = [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .nameKey]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: includeHidden ? [] : [.skipsHiddenFiles]
        ) else { return [] }

        return children.filter { child in
            guard let values = try? child.resourceValues(forKeys: Set(keys)) else { return false }
            if values.isSymbolicLink == true { return false }
            if !includeHidden, values.isHidden == true { return false }
            return values.isDirectory == true || values.isRegularFile == true
        }
    }

    private static func visibleChildSummary(of url: URL, includeHidden: Bool) -> FileTreeChildSummary? {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
        var folderCount = 0
        var folderBytes: Int64 = 0
        var fileCount = 0
        var fileBytes: Int64 = 0

        for child in visibleChildren(of: url, includeHidden: includeHidden) {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            if values.isDirectory == true {
                folderCount += 1
                folderBytes += directoryStats(child, includeHidden: includeHidden).bytes
            } else if values.isRegularFile == true {
                fileCount += 1
                fileBytes += Int64(values.fileSize ?? 0)
            }
        }

        let summary = FileTreeChildSummary(
            folderCount: folderCount,
            folderBytes: folderBytes,
            fileCount: fileCount,
            fileBytes: fileBytes
        )
        return summary.isEmpty ? nil : summary
    }

    private static func directoryStats(_ url: URL, includeHidden: Bool) -> DirectoryStats {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey, .fileSizeKey]
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else { return DirectoryStats() }

        var stats = DirectoryStats()
        for case let item as URL in enumerator {
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }
            if !includeHidden, values.isHidden == true { continue }
            if values.isDirectory == true {
                stats.folderCount += 1
            } else if values.isRegularFile == true {
                stats.fileCount += 1
                stats.bytes += Int64(values.fileSize ?? 0)
            }
        }
        return stats
    }

    private struct BuilderSummary {
        var foldersVisited = 0
        var filesMapped = 0
    }

    private struct DirectoryStats {
        var folderCount = 0
        var fileCount = 0
        var bytes: Int64 = 0
    }
}
