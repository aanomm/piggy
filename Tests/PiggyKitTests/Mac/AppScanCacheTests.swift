import XCTest
@testable import PiggyKit

final class AppScanCacheTests: XCTestCase {
    func testLoadsFreshCacheWhenSourceDatesMatch() throws {
        let cacheURL = try makeTemporaryCacheURL()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let sourceDates = ["/Applications": Date(timeIntervalSince1970: 900)]
        let app = makeApp(name: "Fresh")

        AppScanCache.save([app], to: cacheURL, sourceDirectoryModificationDates: sourceDates, now: createdAt)

        let loaded = AppScanCache.loadIfFresh(
            from: cacheURL,
            sourceDirectoryModificationDates: sourceDates,
            now: createdAt.addingTimeInterval(60),
            maxAge: 600
        )

        XCTAssertEqual(loaded?.map(\.displayName), ["Fresh"])
    }

    func testRejectsStaleCache() throws {
        let cacheURL = try makeTemporaryCacheURL()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let sourceDates = ["/Applications": Date(timeIntervalSince1970: 900)]

        AppScanCache.save([makeApp()], to: cacheURL, sourceDirectoryModificationDates: sourceDates, now: createdAt)

        let loaded = AppScanCache.loadIfFresh(
            from: cacheURL,
            sourceDirectoryModificationDates: sourceDates,
            now: createdAt.addingTimeInterval(601),
            maxAge: 600
        )

        XCTAssertNil(loaded)
    }

    func testRejectsCacheWhenSourceDatesChange() throws {
        let cacheURL = try makeTemporaryCacheURL()
        let createdAt = Date(timeIntervalSince1970: 1_000)

        AppScanCache.save(
            [makeApp()],
            to: cacheURL,
            sourceDirectoryModificationDates: ["/Applications": Date(timeIntervalSince1970: 900)],
            now: createdAt
        )

        let loaded = AppScanCache.loadIfFresh(
            from: cacheURL,
            sourceDirectoryModificationDates: ["/Applications": Date(timeIntervalSince1970: 950)],
            now: createdAt.addingTimeInterval(60),
            maxAge: 600
        )

        XCTAssertNil(loaded)
    }

    private func makeTemporaryCacheURL() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PiggyAppScanCacheTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("apps-v1.json")
    }

    private func makeApp(name: String = "Example") -> AppInfo {
        AppInfo(
            id: name,
            path: URL(fileURLWithPath: "/Applications/\(name).app"),
            displayName: name,
            bundleIdentifier: "com.example.\(name.lowercased())",
            bundleVersion: nil,
            shortVersion: nil,
            minOSVersion: nil,
            size: 1,
            creationDate: nil,
            modificationDate: nil,
            lastUsedDate: nil,
            purpose: nil,
            architecture: .arm64,
            isAppleSigned: false,
            isFromAppStore: false,
            isQuarantined: false,
            agentCount: 0,
            sourceDir: .rootApp
        )
    }
}
