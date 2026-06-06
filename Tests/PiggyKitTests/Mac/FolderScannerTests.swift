import XCTest
@testable import PiggyKit

final class FolderScannerTests: XCTestCase {
    func testScanRanksImmediateFoldersByRecursiveSizeAndCountsFiles() throws {
        let root = try makeTemporaryDirectory()
        let tiny = try makeFolder(named: "Tiny", in: root)
        try writeBytes(3, to: tiny.appendingPathComponent("a.bin"))

        let huge = try makeFolder(named: "Huge", in: root)
        try writeBytes(10, to: huge.appendingPathComponent("b.bin"))
        let nested = try makeFolder(named: "Nested", in: huge)
        try writeBytes(11, to: nested.appendingPathComponent("c.bin"))

        let folders = FolderScanner.scan(root: root, maxDepth: 1)

        XCTAssertEqual(folders.map(\.name), ["Huge", "Tiny"])
        XCTAssertEqual(folders.map(\.totalBytes), [21, 3])
        XCTAssertEqual(folders.map(\.fileCount), [2, 1])
        XCTAssertEqual(folders.map(\.nestedFolderCount), [1, 0])
    }

    func testScanCanIncludeNestedFoldersAsSeparateFindingsWhenDepthAllows() throws {
        let root = try makeTemporaryDirectory()
        let parent = try makeFolder(named: "Parent", in: root)
        let child = try makeFolder(named: "Child", in: parent)
        try writeBytes(5, to: child.appendingPathComponent("child.bin"))

        let folders = FolderScanner.scan(root: root, maxDepth: 2)

        XCTAssertEqual(folders.map(\.name), ["Parent", "Child"])
        XCTAssertEqual(folders.map(\.totalBytes), [5, 5])
    }

    func testScanSummaryReportsUniqueRootBytesWhenNestedFindingsOverlap() throws {
        let root = try makeTemporaryDirectory()
        let parent = try makeFolder(named: "Parent", in: root)
        let child = try makeFolder(named: "Child", in: parent)
        try writeBytes(5, to: child.appendingPathComponent("child.bin"))

        let result = FolderScanner.scanWithSummary(root: root, maxDepth: 2)

        XCTAssertEqual(result.findings.map(\.totalBytes), [5, 5])
        XCTAssertEqual(result.summary.totalBytes, 5)
        XCTAssertEqual(result.summary.filesCounted, 1)
        XCTAssertEqual(result.summary.statusSummary, "3 folders · 1 file · 5 B")
    }

    func testScanSkipsHiddenFilesAndFoldersByDefault() throws {
        let root = try makeTemporaryDirectory()
        let visible = try makeFolder(named: "Visible", in: root)
        try writeBytes(7, to: visible.appendingPathComponent("visible.bin"))
        try writeBytes(13, to: visible.appendingPathComponent(".hidden.bin"))
        let hiddenFolder = try makeFolder(named: ".Secret", in: root)
        try writeBytes(19, to: hiddenFolder.appendingPathComponent("secret.bin"))

        let folders = FolderScanner.scan(root: root, maxDepth: 1)

        XCTAssertEqual(folders.map(\.name), ["Visible"])
        XCTAssertEqual(folders.first?.totalBytes, 7)
        XCTAssertEqual(folders.first?.fileCount, 1)
    }

    func testScanCanFilterByMinimumSize() throws {
        let root = try makeTemporaryDirectory()
        let small = try makeFolder(named: "Small", in: root)
        try writeBytes(5, to: small.appendingPathComponent("small.bin"))
        let large = try makeFolder(named: "Large", in: root)
        try writeBytes(25, to: large.appendingPathComponent("large.bin"))

        let folders = FolderScanner.scan(root: root, maxDepth: 1, minimumBytes: 10)

        XCTAssertEqual(folders.map(\.name), ["Large"])
    }

    func testScanCanIncludeHiddenFilesAndFoldersWhenRequested() throws {
        let root = try makeTemporaryDirectory()
        let visible = try makeFolder(named: "Visible", in: root)
        try writeBytes(7, to: visible.appendingPathComponent("visible.bin"))
        try writeBytes(13, to: visible.appendingPathComponent(".hidden.bin"))
        let hiddenFolder = try makeFolder(named: ".Secret", in: root)
        try writeBytes(19, to: hiddenFolder.appendingPathComponent("secret.bin"))

        let folders = FolderScanner.scan(root: root, maxDepth: 1, includeHidden: true)

        XCTAssertEqual(folders.map(\.name), ["Visible", ".Secret"])
        XCTAssertEqual(folders.map(\.totalBytes), [20, 19])
        XCTAssertEqual(folders.first(where: { $0.name == "Visible" })?.fileCount, 2)
    }

    func testScanDoesNotFollowSymbolicLinksOutsideTheRoot() throws {
        let root = try makeTemporaryDirectory()
        let folder = try makeFolder(named: "Safe", in: root)
        try writeBytes(5, to: folder.appendingPathComponent("safe.bin"))

        let outside = try makeTemporaryDirectory()
        try writeBytes(1_000, to: outside.appendingPathComponent("outside.bin"))
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("outside-link"),
            withDestinationURL: outside
        )

        let folders = FolderScanner.scan(root: root, maxDepth: 1, includeHidden: true)

        XCTAssertEqual(folders.map(\.name), ["Safe"])
        XCTAssertEqual(folders.first?.totalBytes, 5)
        XCTAssertEqual(folders.first?.fileCount, 1)
    }

    func testScanReportsProgressWhileWalkingFoldersAndFiles() throws {
        let root = try makeTemporaryDirectory()
        let first = try makeFolder(named: "First", in: root)
        try writeBytes(4, to: first.appendingPathComponent("one.bin"))
        let second = try makeFolder(named: "Second", in: root)
        try writeBytes(9, to: second.appendingPathComponent("two.bin"))

        var events: [FolderScanProgress] = []
        _ = FolderScanner.scan(root: root, maxDepth: 1) { progress in
            events.append(progress)
        }

        XCTAssertFalse(events.isEmpty)
        XCTAssertGreaterThanOrEqual(events.last?.foldersVisited ?? 0, 3)
        XCTAssertEqual(events.last?.filesCounted, 2)
        XCTAssertEqual(events.last?.bytesCounted, 13)
        XCTAssertEqual(events.last?.statusSummary, "3 folders · 2 files · 13 B")
        XCTAssertTrue(events.contains { $0.currentURL.lastPathComponent == "First" })
        XCTAssertTrue(events.contains { $0.currentURL.lastPathComponent == "Second" })
        XCTAssertEqual(events.map(\.filesCounted), events.map(\.filesCounted).sorted())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PiggyFolderScannerTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    @discardableResult
    private func makeFolder(named name: String, in parent: URL) throws -> URL {
        let url = parent.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeBytes(_ count: Int, to url: URL) throws {
        try Data(repeating: 1, count: count).write(to: url)
    }
}
