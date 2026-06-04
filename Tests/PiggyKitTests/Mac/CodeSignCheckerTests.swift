import Darwin
import XCTest
@testable import PiggyKit

final class CodeSignCheckerTests: XCTestCase {
    func testAppStoreReceiptIsDetectedWhenReceiptDirectoryExists() throws {
        let app = try makeTemporaryAppBundle()
        let receipt = app.appendingPathComponent("Contents/_MASReceipt")
        try FileManager.default.createDirectory(at: receipt, withIntermediateDirectories: true)

        XCTAssertTrue(CodeSignChecker.isFromAppStore(appPath: app))
    }

    func testMissingAppStoreReceiptIsNotDetected() throws {
        let app = try makeTemporaryAppBundle()

        XCTAssertFalse(CodeSignChecker.isFromAppStore(appPath: app))
    }

    func testQuarantineDetectionUsesComAppleQuarantineExtendedAttribute() throws {
        let app = try makeTemporaryAppBundle()
        let marker = "0081;00000000;Safari;"
        try marker.withCString { pointer in
            let result = setxattr(app.path, "com.apple.quarantine", pointer, strlen(pointer), 0, 0)
            if result != 0 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }

        XCTAssertTrue(CodeSignChecker.isQuarantined(appPath: app))
    }

    func testPathWithoutQuarantineExtendedAttributeIsNotQuarantined() throws {
        let app = try makeTemporaryAppBundle()

        XCTAssertFalse(CodeSignChecker.isQuarantined(appPath: app))
    }

    private func makeTemporaryAppBundle() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PiggyCodeSignCheckerTests")
            .appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(
            at: app.appendingPathComponent("Contents/MacOS"),
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return app
    }
}
