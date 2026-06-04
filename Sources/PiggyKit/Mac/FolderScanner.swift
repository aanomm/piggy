import Foundation

public struct FolderFinding: Equatable {
    public let url: URL
    public let name: String
    public let totalBytes: Int64
    public let fileCount: Int
    public let nestedFolderCount: Int

    public var formattedSize: String {
        ByteFormat.string(totalBytes)
    }
}

public enum FolderScanner {
    private struct FolderMetrics {
        var totalBytes: Int64 = 0
        var fileCount: Int = 0
        var folderCount: Int = 0
    }

    public static func scan(
        root: URL,
        maxDepth: Int = 1,
        includeHidden: Bool = false,
        minimumBytes: Int64 = 0
    ) -> [FolderFinding] {
        let depthLimit = max(1, maxDepth)
        let (_, findings) = scanFolder(root, depth: 0, maxDepth: depthLimit, includeHidden: includeHidden)

        return findings
            .filter { $0.totalBytes >= minimumBytes }
            .sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
                if lhs.url.pathComponents.count != rhs.url.pathComponents.count {
                    return lhs.url.pathComponents.count < rhs.url.pathComponents.count
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private static func scanFolder(
        _ folder: URL,
        depth: Int,
        maxDepth: Int,
        includeHidden: Bool
    ) -> (FolderMetrics, [FolderFinding]) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        ) else { return (FolderMetrics(), []) }

        var metrics = FolderMetrics()
        var findings: [FolderFinding] = []

        for child in children {
            guard let values = try? child.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey]) else {
                continue
            }
            if shouldSkip(child, values: values, includeHidden: includeHidden) { continue }

            if values.isRegularFile == true {
                metrics.totalBytes += Int64(values.fileSize ?? 0)
                metrics.fileCount += 1
            } else if values.isDirectory == true {
                let (childMetrics, childFindings) = scanFolder(
                    child,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    includeHidden: includeHidden
                )
                metrics.totalBytes += childMetrics.totalBytes
                metrics.fileCount += childMetrics.fileCount
                metrics.folderCount += 1 + childMetrics.folderCount
                findings.append(contentsOf: childFindings)
            }
        }

        if depth > 0, depth <= maxDepth {
            findings.append(
                FolderFinding(
                    url: folder,
                    name: folder.lastPathComponent,
                    totalBytes: metrics.totalBytes,
                    fileCount: metrics.fileCount,
                    nestedFolderCount: metrics.folderCount
                )
            )
        }

        return (metrics, findings)
    }

    private static func shouldSkip(_ url: URL, values: URLResourceValues, includeHidden: Bool) -> Bool {
        if values.isSymbolicLink == true { return true }
        if includeHidden { return false }
        if url.lastPathComponent.hasPrefix(".") { return true }
        return values.isHidden == true
    }
}
