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
    public static func scan(
        root: URL,
        maxDepth: Int = 1,
        includeHidden: Bool = false,
        minimumBytes: Int64 = 0
    ) -> [FolderFinding] {
        let depthLimit = max(1, maxDepth)
        let candidates = folderCandidates(under: root, depth: 1, maxDepth: depthLimit, includeHidden: includeHidden)

        return candidates
            .map { folder -> FolderFinding in
                let metrics = folderMetrics(for: folder, includeHidden: includeHidden)
                return FolderFinding(
                    url: folder,
                    name: folder.lastPathComponent,
                    totalBytes: metrics.totalBytes,
                    fileCount: metrics.fileCount,
                    nestedFolderCount: metrics.folderCount
                )
            }
            .filter { $0.totalBytes >= minimumBytes }
            .sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
                if lhs.url.pathComponents.count != rhs.url.pathComponents.count {
                    return lhs.url.pathComponents.count < rhs.url.pathComponents.count
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private static func folderCandidates(
        under root: URL,
        depth: Int,
        maxDepth: Int,
        includeHidden: Bool
    ) -> [URL] {
        guard depth <= maxDepth,
              let children = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey],
                options: includeHidden ? [] : [.skipsHiddenFiles]
              ) else { return [] }

        var folders: [URL] = []
        for child in children {
            guard isRealDirectory(child, includeHidden: includeHidden) else { continue }
            folders.append(child)
            folders.append(contentsOf: folderCandidates(under: child, depth: depth + 1, maxDepth: maxDepth, includeHidden: includeHidden))
        }
        return folders
    }

    private static func folderMetrics(for folder: URL, includeHidden: Bool) -> (totalBytes: Int64, fileCount: Int, folderCount: Int) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        ) else { return (0, 0, 0) }

        var totalBytes: Int64 = 0
        var fileCount = 0
        var folderCount = 0

        for child in children {
            if !includeHidden, isHidden(child) { continue }
            if isSymbolicLink(child) { continue }

            let values = try? child.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey])
            if values?.isRegularFile == true {
                totalBytes += Int64(values?.fileSize ?? 0)
                fileCount += 1
            } else if values?.isDirectory == true {
                folderCount += 1
                let nested = folderMetrics(for: child, includeHidden: includeHidden)
                totalBytes += nested.totalBytes
                fileCount += nested.fileCount
                folderCount += nested.folderCount
            }
        }

        return (totalBytes, fileCount, folderCount)
    }

    private static func isRealDirectory(_ url: URL, includeHidden: Bool) -> Bool {
        if !includeHidden, isHidden(url) { return false }
        if isSymbolicLink(url) { return false }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }

    private static func isHidden(_ url: URL) -> Bool {
        if url.lastPathComponent.hasPrefix(".") { return true }
        let values = try? url.resourceValues(forKeys: [.isHiddenKey])
        return values?.isHidden == true
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
        return values?.isSymbolicLink == true
    }
}
