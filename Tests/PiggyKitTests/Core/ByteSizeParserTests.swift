import XCTest
@testable import PiggyKit

final class ByteSizeParserTests: XCTestCase {
    func testParsesPlainBytesAndCommonSuffixes() throws {
        XCTAssertEqual(try ByteSizeParser.parse("42"), 42)
        XCTAssertEqual(try ByteSizeParser.parse("10kb"), 10 * 1_024)
        XCTAssertEqual(try ByteSizeParser.parse("5 MB"), 5 * 1_048_576)
        XCTAssertEqual(try ByteSizeParser.parse("2gb"), 2 * 1_073_741_824)
    }

    func testParsesDecimalValues() throws {
        XCTAssertEqual(try ByteSizeParser.parse("1.5gb"), 1_610_612_736)
    }

    func testRejectsUnknownSizes() {
        XCTAssertThrowsError(try ByteSizeParser.parse("many truffles"))
    }
}
