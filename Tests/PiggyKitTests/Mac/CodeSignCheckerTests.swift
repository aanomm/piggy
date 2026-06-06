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

    func testDetectsArm64ArchitectureWithoutLaunchingExternalTools() throws {
        let app = try makeTemporaryAppBundle(executableName: "Example")
        try writeExecutable(bytes: [
            0xcf, 0xfa, 0xed, 0xfe, // MH_MAGIC_64, little-endian
            0x0c, 0x00, 0x00, 0x01  // CPU_TYPE_ARM64
        ], app: app, executableName: "Example")

        XCTAssertEqual(CodeSignChecker.detectArchitecture(appPath: app), .arm64)
    }

    func testDetectsUniversalFatArchitectureWithoutLaunchingExternalTools() throws {
        let app = try makeTemporaryAppBundle(executableName: "Example")
        try writeExecutable(bytes: [
            0xca, 0xfe, 0xba, 0xbe, // FAT_MAGIC, big-endian
            0x00, 0x00, 0x00, 0x02, // two architectures
            0x01, 0x00, 0x00, 0x0c, // CPU_TYPE_ARM64
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0x01, 0x00, 0x00, 0x07, // CPU_TYPE_X86_64
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ], app: app, executableName: "Example")

        XCTAssertEqual(CodeSignChecker.detectArchitecture(appPath: app), .universal)
    }

    private func makeTemporaryAppBundle(executableName: String? = nil) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PiggyCodeSignCheckerTests")
            .appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(
            at: app.appendingPathComponent("Contents/MacOS"),
            withIntermediateDirectories: true
        )
        if let executableName {
            let plist = """
            <?xml version=\"1.0\" encoding=\"UTF-8\"?>
            <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
            <plist version=\"1.0\">
            <dict>
                <key>CFBundleExecutable</key>
                <string>\(executableName)</string>
            </dict>
            </plist>
            """
            try plist.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        }
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return app
    }

    private func writeExecutable(bytes: [UInt8], app: URL, executableName: String) throws {
        let executable = app.appendingPathComponent("Contents/MacOS").appendingPathComponent(executableName)
        try Data(bytes).write(to: executable)
    }
}
