import Foundation

public enum AppScanCache {
    private struct Payload: Codable {
        let version: Int
        let createdAt: Date
        let sourceDirectoryModificationDates: [String: Date]
        let apps: [AppInfo]
    }

    private static let version = 1
    public static let defaultMaxAge: TimeInterval = 24 * 60 * 60
    public static let fallbackMaxAge: TimeInterval = 7 * 24 * 60 * 60

    public static var cacheURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("piggy", isDirectory: true).appendingPathComponent("apps-v1.json")
    }

    public static func loadIfFresh() -> [AppInfo]? {
        loadIfFresh(maxAge: defaultMaxAge)
    }

    public static func loadIfFresh(maxAge: TimeInterval) -> [AppInfo]? {
        loadIfFresh(
            from: cacheURL,
            sourceDirectoryModificationDates: sourceDirectoryModificationDates(),
            now: Date(),
            maxAge: maxAge
        )
    }

    public static func loadFallback() -> [AppInfo]? {
        load(
            from: cacheURL,
            sourceDirectoryModificationDates: sourceDirectoryModificationDates(),
            now: Date(),
            maxAge: fallbackMaxAge,
            requireSourceDates: false
        )
    }

    public static func loadIfFresh(
        from url: URL,
        sourceDirectoryModificationDates expectedSourceDates: [String: Date],
        now: Date,
        maxAge: TimeInterval
    ) -> [AppInfo]? {
        load(
            from: url,
            sourceDirectoryModificationDates: expectedSourceDates,
            now: now,
            maxAge: maxAge,
            requireSourceDates: true
        )
    }

    public static func load(
        from url: URL,
        sourceDirectoryModificationDates expectedSourceDates: [String: Date],
        now: Date,
        maxAge: TimeInterval,
        requireSourceDates: Bool
    ) -> [AppInfo]? {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == version,
              now.timeIntervalSince(payload.createdAt) <= maxAge,
              !requireSourceDates || payload.sourceDirectoryModificationDates == expectedSourceDates
        else {
            return nil
        }

        return payload.apps
    }

    public static func save(_ apps: [AppInfo]) {
        save(
            apps,
            to: cacheURL,
            sourceDirectoryModificationDates: sourceDirectoryModificationDates(),
            now: Date()
        )
    }

    public static func save(
        _ apps: [AppInfo],
        to url: URL,
        sourceDirectoryModificationDates: [String: Date],
        now: Date
    ) {
        let payload = Payload(
            version: version,
            createdAt: now,
            sourceDirectoryModificationDates: sourceDirectoryModificationDates,
            apps: apps
        )

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            // Cache failures should never block a scan result.
        }
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private static func sourceDirectoryModificationDates() -> [String: Date] {
        var dates: [String: Date] = [:]
        for source in AppInfo.SourceDirectory.allCases {
            let url = URL(fileURLWithPath: source.path)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let modificationDate = attrs[.modificationDate] as? Date {
                dates[source.rawValue] = modificationDate
            }
        }
        return dates
    }
}
