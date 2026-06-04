import XCTest
@testable import PiggyKit

final class RemovalPlanTests: XCTestCase {
    func testBlocksSystemApplicationsFromTrash() {
        let app = makeApp(path: "/System/Applications/Mail.app", source: .system)

        let plan = RemovalPlanner.plan(app: app, relatedFiles: [], includeRelated: false, homeDirectory: "/Users/tester")

        XCTAssertFalse(plan.canTrashApp)
        XCTAssertEqual(plan.appAssessment.level, .blocked)
    }

    func testAllowsRootApplicationsAfterConfirmation() {
        let app = makeApp(path: "/Applications/Sketch.app")

        let plan = RemovalPlanner.plan(app: app, relatedFiles: [], includeRelated: false, homeDirectory: "/Users/tester")

        XCTAssertTrue(plan.canTrashApp)
        XCTAssertEqual(plan.appAssessment.level, .cautious)
    }

    func testWithRelatedIncludesSafeAndCautiousFilesButSkipsSensitiveFiles() {
        let app = makeApp(path: "/Applications/Sketch.app")
        let related = [
            RemovalCandidate(path: URL(fileURLWithPath: "/Users/tester/Library/Caches/com.example.sketch"), size: 10, category: "Caches"),
            RemovalCandidate(path: URL(fileURLWithPath: "/Users/tester/Library/Preferences/com.example.sketch.plist"), size: 1, category: "Preferences"),
            RemovalCandidate(path: URL(fileURLWithPath: "/Users/tester/Library/CloudStorage/Sketch/file"), size: 99, category: "Cloud")
        ]

        let plan = RemovalPlanner.plan(app: app, relatedFiles: related, includeRelated: true, homeDirectory: "/Users/tester")

        XCTAssertEqual(plan.relatedFilesToTrash.map(\.category), ["Caches", "Preferences"])
        XCTAssertEqual(plan.skippedRelatedFiles.map(\.category), ["Cloud"])
    }

    func testWithoutRelatedSkipsAllRelatedFiles() {
        let app = makeApp(path: "/Applications/Sketch.app")
        let related = [RemovalCandidate(path: URL(fileURLWithPath: "/Users/tester/Library/Caches/com.example.sketch"), size: 10, category: "Caches")]

        let plan = RemovalPlanner.plan(app: app, relatedFiles: related, includeRelated: false, homeDirectory: "/Users/tester")

        XCTAssertTrue(plan.relatedFilesToTrash.isEmpty)
        XCTAssertEqual(plan.skippedRelatedFiles.map(\.category), ["Caches"])
    }

    private func makeApp(path: String, source: AppInfo.SourceDirectory = .rootApp) -> AppInfo {
        AppInfo(
            id: path,
            path: URL(fileURLWithPath: path),
            displayName: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
            bundleIdentifier: "com.example.app",
            bundleVersion: nil,
            shortVersion: nil,
            minOSVersion: nil,
            size: 100,
            creationDate: nil,
            modificationDate: nil,
            lastUsedDate: nil,
            purpose: nil,
            architecture: .arm64,
            isAppleSigned: false,
            isFromAppStore: false,
            isQuarantined: false,
            agentCount: 0,
            sourceDir: source
        )
    }
}
