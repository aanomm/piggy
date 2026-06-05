import Foundation
import AppKit
import PiggyKit

enum AppRemover {
    struct RelatedFile {
        let path: URL
        let size: Int64
        let category: String
    }

    struct DeletionResult {
        let appName: String
        let appSize: Int64
        let trashedRelatedFiles: [RelatedFile]
        let skippedRelatedFiles: [RelatedFile]
        let totalFreed: Int64
        let didTrash: Bool
        let failureReason: String?
    }

    struct RelatedDeletionResult {
        let trashed: [RelatedFile]
        let skipped: [RelatedFile]
        let totalFreed: Int64
    }

    struct RelatedFileProgress {
        let checkedCount: Int
        let matchedCount: Int
        let currentURL: URL

        var statusSummary: String {
            "\(checkedCount) places checked · \(matchedCount) crumbs found · \(currentURL.lastPathComponent)"
        }
    }

    struct TrashProgress {
        let phase: String
        let completedCount: Int
        let totalCount: Int?
        let currentURL: URL?

        var statusSummary: String {
            let countSummary = totalCount.map { " \(completedCount)/\($0)" } ?? ""
            let pathSummary = currentURL.map { " · \($0.lastPathComponent)" } ?? ""
            return "\(phase)\(countSummary)\(pathSummary)"
        }
    }

    static func findRelatedFiles(
        for app: AppInfo,
        progress: ((RelatedFileProgress) -> Void)? = nil
    ) -> [RelatedFile] {
        guard let bundleID = app.bundleIdentifier else { return [] }

        let home = NSHomeDirectory()
        var files: [RelatedFile] = []
        var checkedCount = 0

        let searchPaths: [(String, String)] = [
            ("\(home)/Library/Preferences/\(bundleID).plist", "Preferences"),
            ("\(home)/Library/Caches/\(bundleID)", "Caches"),
            ("\(home)/Library/Containers/\(bundleID)", "Containers"),
            ("\(home)/Library/Application Support/\(bundleID)", "App Support"),
            ("\(home)/Library/Saved Application State/\(bundleID).savedState", "Saved State"),
            ("\(home)/Library/Logs/\(bundleID)", "Logs"),
            ("\(home)/Library/WebKit/\(bundleID)", "WebKit"),
        ]

        for (pathStr, category) in searchPaths {
            let url = URL(fileURLWithPath: pathStr)
            checkedCount += 1
            let fm = FileManager.default
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                let size = SizeCalculator.calculateSize(of: url)
                if size > 0 {
                    files.append(RelatedFile(path: url, size: size, category: category))
                }
            }
            progress?(
                RelatedFileProgress(
                    checkedCount: checkedCount,
                    matchedCount: files.count,
                    currentURL: url
                )
            )
        }

        let cookiePattern = "\(home)/Library/HTTPStorages/\(bundleID).binarycookies"
        let cookieURL = URL(fileURLWithPath: cookiePattern)
        checkedCount += 1
        if FileManager.default.fileExists(atPath: cookieURL.path) {
            let size = SizeCalculator.calculateSize(of: cookieURL)
            if size > 0 {
                files.append(RelatedFile(path: cookieURL, size: size, category: "HTTP Cookies"))
            }
        }
        progress?(
            RelatedFileProgress(
                checkedCount: checkedCount,
                matchedCount: files.count,
                currentURL: cookieURL
            )
        )

        let groupContainersDir = URL(fileURLWithPath: "\(home)/Library/Group Containers")
        if let groupContents = try? FileManager.default.contentsOfDirectory(
            at: groupContainersDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) {
            for groupURL in groupContents {
                checkedCount += 1
                let groupName = groupURL.lastPathComponent
                if groupName.contains(bundleID) || isGroupRelated(groupName, to: bundleID) {
                    let size = SizeCalculator.calculateSize(of: groupURL)
                    if size > 0 {
                        files.append(RelatedFile(path: groupURL, size: size, category: "Group Container"))
                    }
                }
                progress?(
                    RelatedFileProgress(
                        checkedCount: checkedCount,
                        matchedCount: files.count,
                        currentURL: groupURL
                    )
                )
            }
        }

        return files
    }

    private static func isGroupRelated(_ groupID: String, to bundleID: String) -> Bool {
        let parts = bundleID.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let teamID = String(parts.prefix(2).joined(separator: "."))
        return groupID.hasPrefix(teamID)
    }

    static func delete(
        app: AppInfo,
        includeRelated: Bool,
        progress: ((TrashProgress) -> Void)? = nil
    ) -> DeletionResult {
        let related = findRelatedFiles(for: app) { relatedProgress in
            progress?(
                TrashProgress(
                    phase: "sniffing related crumbs",
                    completedCount: relatedProgress.checkedCount,
                    totalCount: nil,
                    currentURL: relatedProgress.currentURL
                )
            )
        }
        let relatedCandidates = related.map { RemovalCandidate(path: $0.path, size: $0.size, category: $0.category) }
        let plan = RemovalPlanner.plan(app: app, relatedFiles: relatedCandidates, includeRelated: includeRelated)
        let skipped = plan.skippedRelatedFiles.map(toRelatedFile)

        guard plan.canTrashApp else {
            return DeletionResult(
                appName: app.displayName,
                appSize: app.size,
                trashedRelatedFiles: [],
                skippedRelatedFiles: related,
                totalFreed: 0,
                didTrash: false,
                failureReason: plan.appAssessment.reason
            )
        }

        nonisolated(unsafe) var didTrashMain = false
        nonisolated(unsafe) var failureReason: String?
        let ws = NSWorkspace.shared

        progress?(
            TrashProgress(
                phase: "moving app to Trash",
                completedCount: 0,
                totalCount: 1,
                currentURL: app.path
            )
        )
        let semaphore = DispatchSemaphore(value: 0)
        ws.recycle([app.path]) { _, error in
            if let error = error {
                failureReason = error.localizedDescription
                fputs("piggy: macOS could not move the app to Trash: \(error.localizedDescription)\n", stderr)
            } else {
                didTrashMain = true
            }
            semaphore.signal()
        }
        semaphore.wait()
        progress?(
            TrashProgress(
                phase: didTrashMain ? "app moved to Trash" : "app move failed",
                completedCount: didTrashMain ? 1 : 0,
                totalCount: 1,
                currentURL: app.path
            )
        )

        var trashedRelated: [RelatedFile] = []
        if didTrashMain && includeRelated {
            let totalRelated = plan.relatedFilesToTrash.count
            for (index, candidate) in plan.relatedFilesToTrash.enumerated() {
                let relatedFile = toRelatedFile(candidate)
                progress?(
                    TrashProgress(
                        phase: "moving related crumbs to Trash",
                        completedCount: index,
                        totalCount: totalRelated,
                        currentURL: relatedFile.path
                    )
                )
                let sem = DispatchSemaphore(value: 0)
                nonisolated(unsafe) var didTrashRelated = false
                ws.recycle([relatedFile.path]) { _, error in
                    if let error = error {
                        fputs("piggy: skipped this related app crumb to stay safe: \(relatedFile.path.path) (\(error.localizedDescription))\n", stderr)
                    } else {
                        didTrashRelated = true
                    }
                    sem.signal()
                }
                sem.wait()
                if didTrashRelated { trashedRelated.append(relatedFile) }
                progress?(
                    TrashProgress(
                        phase: "moving related crumbs to Trash",
                        completedCount: index + 1,
                        totalCount: totalRelated,
                        currentURL: relatedFile.path
                    )
                )
            }
        }

        if didTrashMain {
            AppScanCache.clear()
        }

        return DeletionResult(
            appName: app.displayName,
            appSize: app.size,
            trashedRelatedFiles: trashedRelated,
            skippedRelatedFiles: skipped,
            totalFreed: didTrashMain ? app.size + trashedRelated.reduce(0) { $0 + $1.size } : 0,
            didTrash: didTrashMain,
            failureReason: failureReason
        )
    }

    @discardableResult
    static func deleteRelatedFiles(
        _ files: [RelatedFile],
        progress: ((TrashProgress) -> Void)? = nil
    ) -> RelatedDeletionResult {
        let ws = NSWorkspace.shared
        var trashed: [RelatedFile] = []
        var skipped: [RelatedFile] = []

        for (index, file) in files.enumerated() {
            progress?(
                TrashProgress(
                    phase: "checking crumb safety",
                    completedCount: index,
                    totalCount: files.count,
                    currentURL: file.path
                )
            )
            let assessment = SafetyClassifier.assess(path: file.path.path)
            guard assessment.level < .sensitive else {
                skipped.append(file)
                continue
            }

            let sem = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var didTrash = false
            ws.recycle([file.path]) { _, _ in
                didTrash = true
                sem.signal()
            }
            sem.wait()
            if didTrash { trashed.append(file) }
            progress?(
                TrashProgress(
                    phase: "moving crumbs to Trash",
                    completedCount: index + 1,
                    totalCount: files.count,
                    currentURL: file.path
                )
            )
        }

        return RelatedDeletionResult(
            trashed: trashed,
            skipped: skipped,
            totalFreed: trashed.reduce(0) { $0 + $1.size }
        )
    }

    private static func toRelatedFile(_ candidate: RemovalCandidate) -> RelatedFile {
        RelatedFile(path: candidate.path, size: candidate.size, category: candidate.category)
    }
}
