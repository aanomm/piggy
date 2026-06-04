import Foundation

enum AppScanCache {
    private struct Payload: Codable {
        let version: Int
        let createdAt: Date
        let sourceDirectoryModificationDates: [String: Date]
        let apps: [AppInfo]
    }

    private static let version = 1
    private static let maxAge: TimeInterval = 10 * 60

    static var cacheURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("piggy", isDirectory: true).appendingPathComponent("apps-v1.json")
    }

    static func loadIfFresh() -> [AppInfo]? {
        let url = cacheURL
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == version,
              Date().timeIntervalSince(payload.createdAt) <= maxAge,
              payload.sourceDirectoryModificationDates == sourceDirectoryModificationDates()
        else {
            return nil
        }

        return payload.apps
    }

    static func save(_ apps: [AppInfo]) {
        let url = cacheURL
        let payload = Payload(
            version: version,
            createdAt: Date(),
            sourceDirectoryModificationDates: sourceDirectoryModificationDates(),
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

    static func clear() {
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
