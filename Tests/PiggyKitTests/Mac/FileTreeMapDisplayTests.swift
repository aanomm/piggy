import XCTest
@testable import PiggyKit

final class FileTreeMapDisplayTests: XCTestCase {
    func testInlineLimitNoteCombinesHiddenChildrenAndDepthLimit() {
        let node = FileTreeNode(
            name: "Parent",
            url: URL(fileURLWithPath: "/tmp/Parent"),
            isDirectory: true,
            bytes: 42,
            children: [],
            hiddenChildCount: 3,
            isDepthLimited: true
        )

        XCTAssertEqual(node.inlineLimitNote, "… 3 more; … deeper folders hidden by --depth")
    }

    func testInlineLimitNoteDescribesDepthLimitWithoutAddingTreeRows() {
        let node = FileTreeNode(
            name: "Parent",
            url: URL(fileURLWithPath: "/tmp/Parent"),
            isDirectory: true,
            bytes: 42,
            children: [],
            hiddenChildCount: 0,
            isDepthLimited: true
        )

        XCTAssertEqual(node.inlineLimitNote, "… deeper folders hidden by --depth")
    }

    func testMudMapDefaultDepthIsOneLevel() {
        XCTAssertEqual(FileTreeMapper.defaultMaxDepth, 1)
    }

    func testDepthLimitedFolderSummarizesImmediateFoldersAndFiles() throws {
        let root = try makeTemporaryDirectory()
        let parent = root.appendingPathComponent("Parent")
        let folderA = parent.appendingPathComponent("FolderA")
        let folderB = parent.appendingPathComponent("FolderB")
        try FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folderB, withIntermediateDirectories: true)
        try Data("abc".utf8).write(to: parent.appendingPathComponent("file-one.txt"))
        try Data("de".utf8).write(to: folderA.appendingPathComponent("a.txt"))
        try Data("fghi".utf8).write(to: folderB.appendingPathComponent("b.txt"))

        let map = FileTreeMapper.map(root: root, maxDepth: 1, entriesPerFolder: 10)
        let parentNode = try XCTUnwrap(map.root.children.first { $0.name == "Parent" })
        let summary = try XCTUnwrap(parentNode.childSummary)

        XCTAssertTrue(parentNode.isDepthLimited)
        XCTAssertTrue(parentNode.children.isEmpty)
        XCTAssertEqual(summary.folderCount, 2)
        XCTAssertEqual(summary.folderBytes, 6)
        XCTAssertEqual(summary.fileCount, 1)
        XCTAssertEqual(summary.fileBytes, 3)
        XCTAssertEqual(summary.inlineOverview, "2 folders 6 B · 1 file 3 B")
        XCTAssertEqual(parentNode.bytes, 9)
        XCTAssertEqual(map.summary.foldersVisited, 4)
        XCTAssertEqual(map.summary.filesMapped, 3)
        XCTAssertEqual(map.summary.totalBytes, 9)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PiggyFileTreeMapDisplayTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
