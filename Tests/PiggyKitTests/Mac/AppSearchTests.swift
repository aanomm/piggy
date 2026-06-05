import Foundation
import XCTest
@testable import PiggyKit

final class AppSearchTests: XCTestCase {
    func testVisibleNameMatchesIgnoreTechnicalIDsFromWebApps() {
        let brave = makeApp(
            name: "Brave Browser",
            bundleID: "com.brave.Browser",
            purpose: "Privacy-focused web browser"
        )
        let youtube = makeApp(
            name: "YouTube",
            bundleID: "com.brave.Browser.webapp.youtube",
            purpose: nil
        )
        let reddit = makeApp(
            name: "Reddit",
            bundleID: "com.brave.Browser.webapp.reddit",
            purpose: nil
        )

        let results = AppSearch.search([youtube, brave, reddit], query: "brave")

        XCTAssertFalse(results.usedTechnicalFallback)
        XCTAssertEqual(results.apps.map(\.displayName), ["Brave Browser"])
    }

    func testTechnicalIDsAreUsedOnlyWhenNamesDoNotMatch() {
        let youtube = makeApp(
            name: "YouTube",
            bundleID: "com.brave.Browser.webapp.youtube",
            purpose: nil
        )
        let reddit = makeApp(
            name: "Reddit",
            bundleID: "com.brave.Browser.webapp.reddit",
            purpose: nil
        )

        let results = AppSearch.search([youtube, reddit], query: "brave")

        XCTAssertTrue(results.usedTechnicalFallback)
        XCTAssertEqual(results.apps.map(\.displayName), ["Reddit", "YouTube"])
    }

    func testVisibleNameIDSetOnlyIncludesAppNameMatches() {
        let brave = makeApp(name: "Brave Browser", bundleID: "com.brave.Browser")
        let youtube = makeApp(name: "YouTube", bundleID: "com.brave.Browser.webapp.youtube")

        let ids = AppSearch.visibleNameMatchedAppIDs([youtube, brave], query: "brave")

        XCTAssertEqual(ids, [brave.id])
    }

    private func makeApp(name: String, bundleID: String?, purpose: String? = nil) -> AppInfo {
        AppInfo(
            id: bundleID ?? name,
            path: URL(fileURLWithPath: "/Applications/\(name).app"),
            displayName: name,
            bundleIdentifier: bundleID,
            bundleVersion: nil,
            shortVersion: nil,
            minOSVersion: nil,
            size: 1_000,
            creationDate: nil,
            modificationDate: nil,
            lastUsedDate: nil,
            purpose: purpose,
            architecture: .arm64,
            isAppleSigned: false,
            isFromAppStore: false,
            isQuarantined: false,
            agentCount: 0,
            sourceDir: .rootApp
        )
    }
}
