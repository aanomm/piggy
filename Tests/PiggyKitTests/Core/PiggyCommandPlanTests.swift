import XCTest
@testable import PiggyKit

final class PiggyCommandPlanTests: XCTestCase {
    func testSniffParsesWhatAndWhereInNoobGrammar() throws {
        let plan = try PiggyCommandPlan.parse(action: .sniff, words: ["imgs", "~/Pictures"])

        XCTAssertEqual(plan.action, .sniff)
        XCTAssertEqual(plan.what, .imgs)
        XCTAssertEqual(plan.where, "~/Pictures")
        XCTAssertNil(plan.query)
    }

    func testFourLetterWhatsAreCanonical() {
        XCTAssertEqual(PiggyWhat.apps.canonical, "apps")
        XCTAssertEqual(PiggyWhat.imgs.canonical, "imgs")
        XCTAssertEqual(PiggyWhat.vids.canonical, "vids")
        XCTAssertEqual(PiggyWhat.docs.canonical, "docs")
    }

    func testFullWordAliasesQuietlyNormalizeToFourLetterWhats() throws {
        XCTAssertEqual(try PiggyCommandPlan.parse(action: .sniff, words: ["images"]).what, .imgs)
        XCTAssertEqual(try PiggyCommandPlan.parse(action: .sniff, words: ["videos"]).what, .vids)
        XCTAssertEqual(try PiggyCommandPlan.parse(action: .sniff, words: ["documents"]).what, .docs)
    }

    func testSearchParsesWhatQueryAndWhere() throws {
        let plan = try PiggyCommandPlan.parse(action: .search, words: ["docs", "tax", "~/Documents"])

        XCTAssertEqual(plan.what, .docs)
        XCTAssertEqual(plan.query, "tax")
        XCTAssertEqual(plan.where, "~/Documents")
    }

    func testStyeDefaultsToEverythingHere() throws {
        let plan = try PiggyCommandPlan.parse(action: .stye, words: [])

        XCTAssertEqual(plan.action, .stye)
        XCTAssertEqual(plan.what, .everything)
        XCTAssertEqual(plan.where, ".")
    }
}
