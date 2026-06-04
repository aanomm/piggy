import XCTest
@testable import PiggyKit

final class MacAuditTests: XCTestCase {
    func testSummaryCountsRiskyArchitectureAndOrigins() {
        let apps = [
            makeApp(name: "Apple", size: 10, architecture: .arm64, isAppleSigned: true),
            makeApp(name: "Intel", size: 20, architecture: .x86_64),
            makeApp(name: "Mystery", size: 30, architecture: .unknown, isQuarantined: true)
        ]

        let summary = MacAudit.summarize(apps)

        XCTAssertEqual(summary.totalApps, 3)
        XCTAssertEqual(summary.totalBytes, 60)
        XCTAssertEqual(summary.appleSignedApps, 1)
        XCTAssertEqual(summary.thirdPartyApps, 2)
        XCTAssertEqual(summary.rosettaApps, 1)
        XCTAssertEqual(summary.unknownArchitectureApps, 1)
        XCTAssertEqual(summary.quarantinedApps, 1)
    }

    func testSummaryRanksLargestApps() {
        let apps = [
            makeApp(name: "Tiny", size: 1),
            makeApp(name: "Huge", size: 100),
            makeApp(name: "Medium", size: 50)
        ]

        let summary = MacAudit.summarize(apps, topLimit: 2)

        XCTAssertEqual(summary.largestApps.map(\.displayName), ["Huge", "Medium"])
    }

    func testInsightsExplainActionableReadOnlyNextSteps() {
        let apps = [
            makeApp(name: "Intel", size: 20, architecture: .x86_64),
            makeApp(name: "Mystery", size: 30, architecture: .unknown, isQuarantined: true, agentCount: 2)
        ]

        let summary = MacAudit.summarize(apps)

        XCTAssertTrue(summary.insights.contains { $0.title == "Rosetta apps" })
        XCTAssertTrue(summary.insights.contains { $0.title == "Quarantined apps" })
        XCTAssertTrue(summary.insights.contains { $0.title == "Background agents" })
    }

    private func makeApp(
        name: String,
        size: Int64,
        architecture: Architecture = .arm64,
        isAppleSigned: Bool = false,
        isQuarantined: Bool = false,
        agentCount: Int = 0
    ) -> AppInfo {
        AppInfo(
            id: name,
            path: URL(fileURLWithPath: "/Applications/\(name).app"),
            displayName: name,
            bundleIdentifier: "com.example.\(name.lowercased())",
            bundleVersion: nil,
            shortVersion: nil,
            minOSVersion: nil,
            size: size,
            creationDate: nil,
            modificationDate: nil,
            lastUsedDate: nil,
            purpose: nil,
            architecture: architecture,
            isAppleSigned: isAppleSigned,
            isFromAppStore: false,
            isQuarantined: isQuarantined,
            agentCount: agentCount,
            sourceDir: .rootApp
        )
    }
}
