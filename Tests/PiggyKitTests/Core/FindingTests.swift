import XCTest
@testable import PiggyKit

final class FindingTests: XCTestCase {
    func testConfidenceIsClamped() {
        let tooHigh = Finding(
            id: "x",
            title: "Too high",
            explanation: "Confidence should be clamped.",
            severity: .high,
            effort: .small,
            confidence: 2
        )
        XCTAssertEqual(tooHigh.confidence, 1)

        let tooLow = Finding(
            id: "y",
            title: "Too low",
            explanation: "Confidence should be clamped.",
            severity: .high,
            effort: .small,
            confidence: -1
        )
        XCTAssertEqual(tooLow.confidence, 0)
    }

    func testTinyHighConfidenceIssueRanksAboveLargeCriticalIssue() {
        let quickWin = Finding(
            id: "quick-win",
            title: "Compress oversized hero image",
            explanation: "A tiny fix with strong evidence should be surfaced early.",
            severity: .high,
            effort: .tiny,
            confidence: 0.95
        )

        let largerWork = Finding(
            id: "large-work",
            title: "Replace heavy app shell",
            explanation: "Important, but much larger work.",
            severity: .critical,
            effort: .large,
            confidence: 0.9
        )

        XCTAssertEqual([largerWork, quickWin].rankedByPriority().first, quickWin)
    }

    func testRankingFallsBackToSeverityThenTitle() {
        let alpha = Finding(
            id: "a",
            title: "Alpha",
            explanation: "Same score.",
            severity: .medium,
            effort: .small,
            confidence: 1
        )
        let beta = Finding(
            id: "b",
            title: "Beta",
            explanation: "Same score.",
            severity: .medium,
            effort: .small,
            confidence: 1
        )

        XCTAssertEqual([beta, alpha].rankedByPriority(), [alpha, beta])
    }
}
