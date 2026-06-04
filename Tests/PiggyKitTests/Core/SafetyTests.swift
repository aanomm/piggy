import XCTest
@testable import PiggyKit

final class SafetyTests: XCTestCase {
    private let home = "/Users/tester"

    func testBlocksSystemPaths() {
        XCTAssertEqual(SafetyClassifier.assess(path: "/System/Applications/Mail.app", homeDirectory: home).level, .blocked)
        XCTAssertEqual(SafetyClassifier.assess(path: "/", homeDirectory: home).level, .blocked)
    }

    func testMarksApplicationsAsCautious() {
        XCTAssertEqual(SafetyClassifier.assess(path: "/Applications/Example.app", homeDirectory: home).level, .cautious)
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Applications/Example.app", homeDirectory: home).level, .cautious)
    }

    func testMarksCloudPathsAsSensitive() {
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Library/Mobile Documents/com~apple~CloudDocs/file", homeDirectory: home).level, .sensitive)
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Library/CloudStorage/Dropbox/file", homeDirectory: home).level, .sensitive)
    }

    func testMarksCachesAndLogsAsSafeReview() {
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Library/Caches/com.example.App", homeDirectory: home).level, .safeReview)
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Library/Logs/com.example.App", homeDirectory: home).level, .safeReview)
    }

    func testMarksContainersAsCautious() {
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Library/Containers/com.example.App", homeDirectory: home).level, .cautious)
        XCTAssertEqual(SafetyClassifier.assess(path: "/Users/tester/Library/Application Support/com.example.App", homeDirectory: home).level, .cautious)
    }
}
