import Foundation
import PiggyKit

struct OrphanInfo {
    let path: URL
    let size: Int64
    let category: String
    let likelyAppName: String?

    var formattedSize: String {
        let absSize = abs(size)
        switch absSize {
        case 0..<1024: return "\(size) B"
        case 1024..<1_048_576: return String(format: "%.1f KB", Double(absSize) / 1024)
        case 1_048_576..<1_073_741_824: return String(format: "%.1f MB", Double(absSize) / 1_048_576)
        default: return String(format: "%.2f GB", Double(absSize) / 1_073_741_824)
        }
    }
}

struct OrphanScanProgress {
    let categoriesVisited: Int
    let itemsChecked: Int
    let orphansFound: Int
    let currentURL: URL

    var statusSummary: String {
        "\(categoriesVisited) places · \(itemsChecked) crumbs checked · \(orphansFound) possible leftovers"
    }
}

enum OrphanScanner {
    static func scan(
        installedBundleIDs: Set<String>,
        progress: ((OrphanScanProgress) -> Void)? = nil
    ) -> [OrphanInfo] {
        let home = NSHomeDirectory()
        let searchDirs: [(String, String)] = [
            ("\(home)/Library/Preferences", "Preferences"),
            ("\(home)/Library/Caches", "Caches"),
            ("\(home)/Library/Containers", "Containers"),
            ("\(home)/Library/Application Support", "App Support"),
            ("\(home)/Library/Saved Application State", "Saved State"),
            ("\(home)/Library/Logs", "Logs"),
            ("\(home)/Library/Group Containers", "Group Container"),
        ]

        var orphans: [OrphanInfo] = []
        var categoriesVisited = 0
        var itemsChecked = 0
        var orphansFound = 0

        for (dirPath, category) in searchDirs {
            categoriesVisited += 1
            let dirURL = URL(fileURLWithPath: dirPath)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                itemsChecked += 1
                let name = url.lastPathComponent
                let nameWithoutExt = url.deletingPathExtension().lastPathComponent

                if isOrphanCandidate(name: name, nameWithoutExt: nameWithoutExt, installedIDs: installedBundleIDs, category: category) {
                    let size = SizeCalculator.calculateSize(of: url)
                    if size > 0 {
                        let appName = resolveLikelyAppName(dirName: nameWithoutExt)
                        orphansFound += 1
                        orphans.append(OrphanInfo(
                            path: url,
                            size: size,
                            category: category,
                            likelyAppName: appName
                        ))
                    }
                }
                progress?(
                    OrphanScanProgress(
                        categoriesVisited: categoriesVisited,
                        itemsChecked: itemsChecked,
                        orphansFound: orphansFound,
                        currentURL: url
                    )
                )
            }
        }

        return orphans.sorted { $0.size > $1.size }
    }

    private static func isOrphanCandidate(
        name: String,
        nameWithoutExt: String,
        installedIDs: Set<String>,
        category: String
    ) -> Bool {
        if name == ".DS_Store" { return false }

        if name.hasSuffix(".plist") {
            let stem = nameWithoutExt
            if installedIDs.contains(stem) { return false }
            for id in installedIDs {
                if stem.contains(id) || id.contains(stem) { return false }
            }
            if stem.contains("."), stem.components(separatedBy: ".").count >= 3 {
                return true
            }
        }

        if category == "Containers" || category == "Group Container" {
            if installedIDs.contains(nameWithoutExt) { return false }
            for id in installedIDs {
                if nameWithoutExt.hasPrefix(id) || id.hasPrefix(nameWithoutExt) { return false }
            }
            if nameWithoutExt.contains("."), nameWithoutExt.components(separatedBy: ".").count >= 3 {
                return true
            }
        }

        if category == "Caches" || category == "Saved State" || category == "Logs" || category == "App Support" {
            if installedIDs.contains(name) { return false }
            for id in installedIDs {
                if name.hasPrefix(id) || id.hasPrefix(name) { return false }
            }
            if name.contains("."), name.components(separatedBy: ".").count >= 3 {
                return true
            }
        }

        return false
    }

    private static func resolveLikelyAppName(dirName: String) -> String? {
        let components = dirName.split(separator: ".")
        guard components.count >= 3 else { return nil }

        let org = components.dropLast()
        guard let last = org.last else { return nil }
        var name = String(last).replacingOccurrences(of: "-", with: " ")

        if name.first?.isLowercase == true {
            name = name.prefix(1).uppercased() + name.dropFirst()
        }

        return name
    }
}
