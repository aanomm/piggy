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
