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

public struct FileTreeNode: Equatable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let bytes: Int64
    public let children: [FileTreeNode]
    public let hiddenChildCount: Int
    public let isDepthLimited: Bool

    public var formattedSize: String { ByteFormat.string(bytes) }
}

public enum FileTreeMapper {
    public static func map(
        root: URL,
        maxDepth: Int = 3,
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
            return FileTreeNode(
                name: name,
                url: url,
                isDirectory: true,
                bytes: directoryByteCount(url, includeHidden: includeHidden),
                children: [],
                hiddenChildCount: 0,
                isDepthLimited: true
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

    private static func directoryByteCount(_ url: URL, includeHidden: Bool) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .isSymbolicLinkKey, .fileSizeKey]
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else { return 0 }

        var total: Int64 = 0
        for case let item as URL in enumerator {
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }
            if !includeHidden, values.isHidden == true { continue }
            if values.isRegularFile == true { total += Int64(values.fileSize ?? 0) }
        }
        return total
    }

    private struct BuilderSummary {
        var foldersVisited = 0
        var filesMapped = 0
    }
}
