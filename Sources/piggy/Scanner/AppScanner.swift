import Foundation
import PiggyKit

enum AppScanner {
    static func scan(progress: ((Int, Int, String) -> Void)? = nil) -> [AppInfo] {
        PurposeLookup.load()
        let agents = AgentScanner.scanAllAgents()

        let appBundles = AppInfo.SourceDirectory.allCases.flatMap { source in
            discoverAppBundles(in: source).map { (url: $0, source: source) }
        }

        var apps: [AppInfo] = []
        for (index, bundle) in appBundles.enumerated() {
            progress?(index + 1, appBundles.count, bundle.url.lastPathComponent)
            if let info = parseApp(at: bundle.url, source: bundle.source, agents: agents) {
                apps.append(info)
            }
        }

        return apps
    }

    private static func discoverAppBundles(in source: AppInfo.SourceDirectory) -> [URL] {
        let dirPath = source.path
        let dirURL = URL(fileURLWithPath: dirPath)

        guard let enumerator = FileManager.default.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var appBundles: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                appBundles.append(url)
            }
        }

        return appBundles
    }

    private static func parseApp(
        at url: URL,
        source: AppInfo.SourceDirectory,
        agents: [String: [AgentScanner.AgentInfo]]
    ) -> AppInfo? {
        let infoPlistPath = url.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistPath) else {
            return createMinimalAppInfo(at: url, source: source, agents: agents)
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: &format) as? [String: Any]

        let bundleID = plist?["CFBundleIdentifier"] as? String
        let displayName = (plist?["CFBundleDisplayName"] as? String)
            ?? (plist?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bundleVersion = plist?["CFBundleVersion"] as? String
        let shortVersion = plist?["CFBundleShortVersionString"] as? String
        let minOSVersion = plist?["LSMinimumSystemVersion"] as? String
        let plistDescription = plist?["CFBundleDescription"] as? String
        let categoryType = plist?["LSApplicationCategoryType"] as? String
        let genres = plist?["LSApplicationSecondaryCategoryType"] as? [String]

        let purpose = plistDescription
            ?? PurposeLookup.purpose(for: bundleID)
            ?? spotlightPurpose(for: bundleID)
            ?? categoryLabel(categoryType)
            ?? genreLabel(genres)

        let size = SizeCalculator.calculateSize(of: url)
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)

        let creationDate = attrs?[.creationDate] as? Date
        let modificationDate = attrs?[.modificationDate] as? Date

        let lastUsedDate = getLastUsedDate(for: bundleID ?? "")

        let arch = CodeSignChecker.detectArchitecture(appPath: url)
        let appleSigned = CodeSignChecker.isAppleSigned(appPath: url)
        let storeApp = CodeSignChecker.isFromAppStore(appPath: url)
        let quarantined = CodeSignChecker.isQuarantined(appPath: url)

        let agentCount = bundleID.map { AgentScanner.countForBundleID($0, in: agents) } ?? 0

        return AppInfo(
            id: bundleID ?? url.path,
            path: url,
            displayName: displayName,
            bundleIdentifier: bundleID,
            bundleVersion: bundleVersion,
            shortVersion: shortVersion,
            minOSVersion: minOSVersion,
            size: size,
            creationDate: creationDate,
            modificationDate: modificationDate,
            lastUsedDate: lastUsedDate,
            purpose: purpose,
            architecture: arch,
            isAppleSigned: appleSigned,
            isFromAppStore: storeApp,
            isQuarantined: quarantined,
            agentCount: agentCount,
            sourceDir: source
        )
    }

    private static func createMinimalAppInfo(
        at url: URL,
        source: AppInfo.SourceDirectory,
        agents: [String: [AgentScanner.AgentInfo]]
    ) -> AppInfo {
        let name = url.deletingPathExtension().lastPathComponent
        let size = SizeCalculator.calculateSize(of: url)
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let arch = CodeSignChecker.detectArchitecture(appPath: url)
        let appleSigned = CodeSignChecker.isAppleSigned(appPath: url)
        let storeApp = CodeSignChecker.isFromAppStore(appPath: url)

        return AppInfo(
            id: url.path,
            path: url,
            displayName: name,
            bundleIdentifier: nil,
            bundleVersion: nil,
            shortVersion: nil,
            minOSVersion: nil,
            size: size,
            creationDate: attrs?[.creationDate] as? Date,
            modificationDate: attrs?[.modificationDate] as? Date,
            lastUsedDate: nil,
            purpose: nil,
            architecture: arch,
            isAppleSigned: appleSigned,
            isFromAppStore: storeApp,
            isQuarantined: false,
            agentCount: 0,
            sourceDir: source
        )
    }

    private static func getLastUsedDate(for bundleID: String) -> Date? {
        let task = Process()
        task.launchPath = "/usr/bin/mdls"
        task.arguments = [
            "-raw",
            "-name", "kMDItemLastUsedDate",
            "-name", "kMDItemContentCreationDate",
        ]

        let query = "kMDItemCFBundleIdentifier == '\(bundleID)'"
        task.arguments?.append(query)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty, output != "(null)"
        else { return nil }

        let formatter = ISO8601DateFormatter()
        return formatter.date(from: output)
    }

    static func singleApp(at path: String) -> AppInfo? {
        let url = URL(fileURLWithPath: path)
        let resolved: AppInfo.SourceDirectory
        let stdPath = url.standardizedFileURL.path
        let userAppPath = URL(fileURLWithPath: AppInfo.SourceDirectory.userApp.path).standardizedFileURL.path
        if stdPath.hasPrefix("/System/Applications") {
            resolved = .system
        } else if stdPath.hasPrefix(userAppPath) {
            resolved = .userApp
        } else {
            resolved = .rootApp
        }

        return parseApp(at: url, source: resolved, agents: AgentScanner.scanAllAgents())
    }

    private static func spotlightPurpose(for bundleID: String?) -> String? {
        guard let bid = bundleID, !bid.isEmpty else { return nil }
        let task = Process()
        task.launchPath = "/usr/bin/mdls"
        task.arguments = ["-raw", "-name", "kMDItemDescription"]
        let query = "kMDItemCFBundleIdentifier == '\(bid)'"
        task.arguments?.append(query)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run(); task.waitUntilExit() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty, output != "(null)" else { return nil }
        return String(output.prefix(120))
    }

    private static func categoryLabel(_ catType: String?) -> String? {
        guard let cat = catType else { return nil }
        let known: [String: String] = [
            "public.app-category.productivity": "Productivity app",
            "public.app-category.developer-tools": "Developer tool",
            "public.app-category.business": "Business app",
            "public.app-category.education": "Education app",
            "public.app-category.entertainment": "Entertainment app",
            "public.app-category.finance": "Finance app",
            "public.app-category.games": "Game",
            "public.app-category.graphics-design": "Graphics & design app",
            "public.app-category.healthcare-fitness": "Health & fitness app",
            "public.app-category.lifestyle": "Lifestyle app",
            "public.app-category.medical": "Medical app",
            "public.app-category.music": "Music app",
            "public.app-category.news": "News app",
            "public.app-category.photography": "Photography app",
            "public.app-category.reference": "Reference app",
            "public.app-category.social-networking": "Social networking app",
            "public.app-category.sports": "Sports app",
            "public.app-category.travel": "Travel app",
            "public.app-category.utilities": "Utility app",
            "public.app-category.video": "Video app",
            "public.app-category.weather": "Weather app",
            "public.app-category.book": "Book app",
            "public.app-category.navigation": "Navigation app",
            "public.app-category.role-playing-games": "RPG game",
            "public.app-category.simulation-games": "Simulation game",
            "public.app-category.action-games": "Action game",
            "public.app-category.adventure-games": "Adventure game",
            "public.app-category.board-games": "Board game",
            "public.app-category.card-games": "Card game",
            "public.app-category.casual-games": "Casual game",
            "public.app-category.family-games": "Family game",
            "public.app-category.music-games": "Music game",
            "public.app-category.puzzle-games": "Puzzle game",
            "public.app-category.racing-games": "Racing game",
            "public.app-category.sports-games": "Sports game",
            "public.app-category.strategy-games": "Strategy game",
            "public.app-category.trivia-games": "Trivia game",
            "public.app-category.word-games": "Word game",
        ]
        return known[cat]
    }

    private static func genreLabel(_ genres: [String]?) -> String? {
        guard let first = genres?.first else { return nil }
        return categoryLabel(first)
    }
}
