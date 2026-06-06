import XCTest
@testable import PiggyKit

final class FileTreeMapperTests: XCTestCase {
    func testMapBuildsAFileTreeWithUniqueRootBytes() throws {
        let root = try makeTemporaryDirectory()
        let parent = try makeFolder(named: "Parent", in: root)
        let child = try makeFolder(named: "Child", in: parent)
        try writeBytes(5, to: child.appendingPathComponent("child.bin"))
        try writeBytes(3, to: root.appendingPathComponent("root.txt"))

        let map = FileTreeMapper.map(root: root, maxDepth: 3, entriesPerFolder: 10)

        XCTAssertEqual(map.summary.foldersVisited, 3)
        XCTAssertEqual(map.summary.filesMapped, 2)
        XCTAssertEqual(map.summary.totalBytes, 8)
        XCTAssertEqual(map.summary.statusSummary, "3 folders · 2 files · 8 B")
        XCTAssertEqual(map.root.children.map(\.name), ["Parent", "root.txt"])
        XCTAssertEqual(map.root.children.first?.children.map(\.name), ["Child"])
        XCTAssertEqual(map.root.children.first?.children.first?.children.map(\.name), ["child.bin"])
    }

    func testMapLimitsDisplayedEntriesPerFolderWithoutChangingTotalBytes() throws {
        let root = try makeTemporaryDirectory()
        try writeBytes(1, to: root.appendingPathComponent("a.txt"))
        try writeBytes(2, to: root.appendingPathComponent("b.txt"))
        try writeBytes(3, to: root.appendingPathComponent("c.txt"))

        let map = FileTreeMapper.map(root: root, maxDepth: 1, entriesPerFolder: 2)

        XCTAssertEqual(map.root.children.map(\.name), ["a.txt", "b.txt"])
        XCTAssertEqual(map.root.hiddenChildCount, 1)
        XCTAssertEqual(map.summary.filesMapped, 3)
        XCTAssertEqual(map.summary.totalBytes, 6)
    }

    func testMapSkipsHiddenFilesByDefault() throws {
        let root = try makeTemporaryDirectory()
        try writeBytes(4, to: root.appendingPathComponent("visible.txt"))
        try writeBytes(9, to: root.appendingPathComponent(".hidden.txt"))

        let map = FileTreeMapper.map(root: root, maxDepth: 1)

        XCTAssertEqual(map.root.children.map(\.name), ["visible.txt"])
        XCTAssertEqual(map.summary.filesMapped, 1)
        XCTAssertEqual(map.summary.totalBytes, 4)
    }

    func testMapDoesNotFollowSymbolicLinksOutsideRoot() throws {
        let root = try makeTemporaryDirectory()
        let outside = try makeTemporaryDirectory()
        try writeBytes(1_000, to: outside.appendingPathComponent("outside.bin"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("outside-link"),
            withDestinationURL: outside
        )

        let map = FileTreeMapper.map(root: root, maxDepth: 2, includeHidden: true)

        XCTAssertTrue(map.root.children.isEmpty)
        XCTAssertEqual(map.summary.totalBytes, 0)
        XCTAssertEqual(map.summary.filesMapped, 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PiggyFileTreeMapperTests")
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
