import Foundation
import AppKit

enum AppRemover {
    struct RelatedFile {
        let path: URL
        let size: Int64
        let category: String
    }

    struct DeletionResult {
        let appName: String
        let appSize: Int64
        let relatedFiles: [RelatedFile]
        let totalFreed: Int64
        let didTrash: Bool
    }

    static func findRelatedFiles(for app: AppInfo) -> [RelatedFile] {
        guard let bundleID = app.bundleIdentifier else { return [] }

        let home = NSHomeDirectory()
        var files: [RelatedFile] = []

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
            let fm = FileManager.default
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                let size = SizeCalculator.calculateSize(of: url)
                if size > 0 {
                    files.append(RelatedFile(path: url, size: size, category: category))
                }
            }
        }

        let cookiePattern = "\(home)/Library/HTTPStorages/\(bundleID).binarycookies"
        let cookieURL = URL(fileURLWithPath: cookiePattern)
        if FileManager.default.fileExists(atPath: cookieURL.path) {
            let size = SizeCalculator.calculateSize(of: cookieURL)
            if size > 0 {
                files.append(RelatedFile(path: cookieURL, size: size, category: "HTTP Cookies"))
            }
        }

        let groupContainersDir = URL(fileURLWithPath: "\(home)/Library/Group Containers")
        if let groupContents = try? FileManager.default.contentsOfDirectory(
            at: groupContainersDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) {
            for groupURL in groupContents {
                let groupName = groupURL.lastPathComponent
                if groupName.contains(bundleID) || isGroupRelated(groupName, to: bundleID) {
                    let size = SizeCalculator.calculateSize(of: groupURL)
                    if size > 0 {
                        files.append(RelatedFile(path: groupURL, size: size, category: "Group Container"))
                    }
                }
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

    static func delete(app: AppInfo, includeRelated: Bool) -> DeletionResult {
        let related = findRelatedFiles(for: app)
        var totalFreed: Int64 = app.size
        for rf in related { totalFreed += rf.size }

        nonisolated(unsafe) var didTrashMain = false
        let ws = NSWorkspace.shared

        let semaphore = DispatchSemaphore(value: 0)
        ws.recycle([app.path]) { urls, error in
            if let error = error {
                fputs("piggy: failed to trash main app: \(error.localizedDescription)\n", stderr)
            } else {
                didTrashMain = true
            }
            semaphore.signal()
        }
        semaphore.wait()

        if includeRelated {
            for relatedFile in related {
                let sem = DispatchSemaphore(value: 0)
                ws.recycle([relatedFile.path]) { _, _ in sem.signal() }
                sem.wait()
            }
        }

        if didTrashMain {
            AppScanCache.clear()
        }

        return DeletionResult(
            appName: app.displayName,
            appSize: app.size,
            relatedFiles: related,
            totalFreed: totalFreed,
            didTrash: didTrashMain
        )
    }

    static func deleteRelatedFiles(_ files: [RelatedFile]) {
        let ws = NSWorkspace.shared
        for file in files {
            let sem = DispatchSemaphore(value: 0)
            ws.recycle([file.path]) { _, _ in sem.signal() }
            sem.wait()
        }
    }
}
