import XCTest
@testable import PiggyKit

final class TerminalStyleTests: XCTestCase {
    func testColorsAreDisabledWhenStdoutIsNotATerminal() {
        XCTAssertFalse(TerminalStyle.colorsEnabled(environment: [:], stdoutIsTTY: false))
        XCTAssertEqual(TerminalStyle.ansi("31", environment: [:], stdoutIsTTY: false), "")
    }

    func testNoColorDisablesAnsiOutput() {
        XCTAssertFalse(TerminalStyle.colorsEnabled(environment: ["NO_COLOR": "1"], stdoutIsTTY: true))
    }

    func testPiggyColorCanForceOrDisableColor() {
        XCTAssertTrue(TerminalStyle.colorsEnabled(environment: ["PIGGY_COLOR": "always", "NO_COLOR": "1"], stdoutIsTTY: false))
        XCTAssertFalse(TerminalStyle.colorsEnabled(environment: ["PIGGY_COLOR": "never"], stdoutIsTTY: true))
    }

    func testDumbTerminalDisablesColor() {
        XCTAssertFalse(TerminalStyle.colorsEnabled(environment: ["TERM": "dumb"], stdoutIsTTY: true))
    }
}
