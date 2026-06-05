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

public struct FolderScanProgress: Equatable {
    public let foldersVisited: Int
    public let filesCounted: Int
    public let bytesCounted: Int64
    public let currentURL: URL

    public init(foldersVisited: Int, filesCounted: Int, bytesCounted: Int64, currentURL: URL) {
        self.foldersVisited = foldersVisited
        self.filesCounted = filesCounted
        self.bytesCounted = bytesCounted
        self.currentURL = currentURL
    }

    public var statusSummary: String {
        "\(foldersVisited) folders · \(filesCounted) files · \(ByteFormat.string(bytesCounted))"
    }
}

public enum FolderScanner {
    private struct FolderMetrics {
        var totalBytes: Int64 = 0
        var fileCount: Int = 0
        var folderCount: Int = 0
    }

    private struct ScanProgressState {
        var foldersVisited: Int = 0
        var filesCounted: Int = 0
        var bytesCounted: Int64 = 0

        mutating func visitedFolder(_ url: URL, progress: ((FolderScanProgress) -> Void)?) {
            foldersVisited += 1
            emit(url, progress: progress)
        }

        mutating func countedFile(_ url: URL, bytes: Int64, progress: ((FolderScanProgress) -> Void)?) {
            filesCounted += 1
            bytesCounted += bytes
            emit(url, progress: progress)
        }

        private func emit(_ url: URL, progress: ((FolderScanProgress) -> Void)?) {
            progress?(
                FolderScanProgress(
                    foldersVisited: foldersVisited,
                    filesCounted: filesCounted,
                    bytesCounted: bytesCounted,
                    currentURL: url
                )
            )
        }
    }

    public static func scan(
        root: URL,
        maxDepth: Int = 1,
        includeHidden: Bool = false,
        minimumBytes: Int64 = 0,
        progress: ((FolderScanProgress) -> Void)? = nil
    ) -> [FolderFinding] {
        let depthLimit = max(1, maxDepth)
        var progressState = ScanProgressState()
        let (_, findings) = scanFolder(
            root,
            depth: 0,
            maxDepth: depthLimit,
            includeHidden: includeHidden,
            progressState: &progressState,
            progress: progress
        )

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
        includeHidden: Bool,
        progressState: inout ScanProgressState,
        progress: ((FolderScanProgress) -> Void)?
    ) -> (FolderMetrics, [FolderFinding]) {
        progressState.visitedFolder(folder, progress: progress)
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
                let bytes = Int64(values.fileSize ?? 0)
                metrics.totalBytes += bytes
                metrics.fileCount += 1
                progressState.countedFile(child, bytes: bytes, progress: progress)
            } else if values.isDirectory == true {
                let (childMetrics, childFindings) = scanFolder(
                    child,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    includeHidden: includeHidden,
                    progressState: &progressState,
                    progress: progress
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
