import XCTest
@testable import PiggyKit

final class SizeCalculatorTests: XCTestCase {
    func testCalculatesNestedRegularFileSizes() throws {
        let root = try makeTemporaryDirectory()
        try Data(repeating: 1, count: 7).write(to: root.appendingPathComponent("a.bin"))

        let nested = root.appendingPathComponent("Nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 11).write(to: nested.appendingPathComponent("b.bin"))

        XCTAssertEqual(SizeCalculator.calculateSize(of: root), 18)
    }

    func testMissingPathReportsZeroBytes() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        XCTAssertEqual(SizeCalculator.calculateSize(of: missing), 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PiggyKitTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
