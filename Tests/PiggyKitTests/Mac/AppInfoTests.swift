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

    private func makeApp(
        name: String = "Example",
        path: String = "/Applications/Example.app",
        size: Int64 = 42,
        architecture: Architecture = .arm64,
        isAppleSigned: Bool = false,
        isFromAppStore: Bool = false,
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
            isQuarantined: false,
            agentCount: 0,
            sourceDir: source
        )
    }
}
