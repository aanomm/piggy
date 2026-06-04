import XCTest
@testable import PiggyKit

final class ByteFormatTests: XCTestCase {
    func testFormatsBytes() {
        XCTAssertEqual(ByteFormat.string(0), "0 B")
        XCTAssertEqual(ByteFormat.string(512), "512 B")
    }

    func testFormatsKilobytes() {
        XCTAssertEqual(ByteFormat.string(1_536), "1.5 KB")
    }

    func testFormatsMegabytes() {
        XCTAssertEqual(ByteFormat.string(1_048_576), "1.0 MB")
    }

    func testFormatsGigabytes() {
        XCTAssertEqual(ByteFormat.string(1_073_741_824), "1.00 GB")
    }
}
