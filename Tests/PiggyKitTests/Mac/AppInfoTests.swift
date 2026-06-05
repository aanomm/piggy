import XCTest
@testable import PiggyKit

final class AppInfoTests: XCTestCase {
    func testAppInfoSourceLabelUsesKnownApplicationRoots() {
        let systemApp = makeApp(path: "/System/Applications/Mail.app")
        let rootApp = makeApp(path: "/Applications/Sketch.app")
        let userApp = makeApp(path: "\(NSHomeDirectory())/Applications/Toy.app")

        XCTAssertEqual(systemApp.sourceLabel, "System")
        XCTAssertEqual(rootApp.sourceLabel, "System-wide")
        XCTAssertEqual(userApp.sourceLabel, "User")
    }

    func testSortKeyRanksLargestAppsFirstByDefaultComparator() {
        let small = makeApp(name: "Small", size: 10)
        let large = makeApp(name: "Large", size: 100)

        let sorted = [small, large].sorted(by: SortKey.comparator(.size, ascending: false))

        XCTAssertEqual(sorted.map(\.displayName), ["Large", "Small"])
    }

    func testSortKeyAcceptsCliAliases() {
        XCTAssertEqual(SortKey(argument: "arch"), .architecture)
        XCTAssertEqual(SortKey(argument: "architecture"), .architecture)
        XCTAssertEqual(SortKey(argument: "used"), .used)
        XCTAssertNil(SortKey(argument: "surprise"))
    }

    func testArchitectureLabelsRemainUserReadable() {
        XCTAssertEqual(Architecture.universal.label, "Universal (arm64 + x86_64)")
        XCTAssertEqual(Architecture.x86_64.shortLabel, "x86_64")
    }

    func testCreatedSortLabelUsesBundledCopy() {
        XCTAssertEqual(SortKey.created.label, "Bundled")
    }

    func testAppReportRecordUsesAgentFriendlyFieldsAndFlagReasons() {
        let app = makeApp(
            name: "Odd Tool",
            path: "/Applications/Odd Tool.app",
            size: 1_048_576,
            architecture: .x86_64,
            isQuarantined: true,
            agentCount: 2
        )

        let record = AppReportRecord(app: app)

        XCTAssertEqual(record.name, "Odd Tool")
        XCTAssertEqual(record.path, "/Applications/Odd Tool.app")
        XCTAssertEqual(record.sizeBytes, 1_048_576)
        XCTAssertEqual(record.sizeFormatted, "1.0 MB")
        XCTAssertEqual(record.architecture, "x86_64")
        XCTAssertEqual(record.architectureLabel, "x86_64 (Intel/Rosetta)")
        XCTAssertEqual(record.scope, "System-wide")
        XCTAssertEqual(record.installedBy, "Direct")
        XCTAssertEqual(record.flagged, ["Rosetta", "Downloaded"])
        XCTAssertEqual(record.helpers, 2)
    }

    func testAppReportRecordEncodesSnakeCaseJson() throws {
        let app = makeApp(name: "Store Tool", isFromAppStore: true)

        let json = try AppReportRecord.encodeJSON([app])

        XCTAssertTrue(json.contains("\"size_bytes\""))
        XCTAssertTrue(json.contains("\"installed_by\""))
        XCTAssertTrue(json.contains("\"flagged\""))
        XCTAssertTrue(json.contains("\"app_store\""))
    }

    private func makeApp(
        name: String = "Example",
        path: String = "/Applications/Example.app",
        size: Int64 = 42,
        architecture: Architecture = .arm64,
        isAppleSigned: Bool = false,
        isFromAppStore: Bool = false,
        isQuarantined: Bool = false,
        agentCount: Int = 0,
        source: AppInfo.SourceDirectory = .rootApp
    ) -> AppInfo {
        AppInfo(
            id: path,
            path: URL(fileURLWithPath: path),
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
            isFromAppStore: isFromAppStore,
            isQuarantined: isQuarantined,
            agentCount: agentCount,
            sourceDir: source
        )
    }
}
