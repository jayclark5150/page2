import XCTest
@testable import Page2

final class BlindspotFinderTests: XCTestCase {

    func testRightMissedStoryIsLeftDominant() {
        // 6 outlets: 5 left, 1 center, 0 right. Right missed it.
        let side = BlindspotFinder.side(leftOutlets: 5, centerOutlets: 1, rightOutlets: 0)
        XCTAssertEqual(side, .right)
    }

    func testLeftMissedStoryIsRightDominant() {
        let side = BlindspotFinder.side(leftOutlets: 0, centerOutlets: 1, rightOutlets: 5)
        XCTAssertEqual(side, .left)
    }

    func testBalancedStoryIsNotABlindspot() {
        let side = BlindspotFinder.side(leftOutlets: 3, centerOutlets: 2, rightOutlets: 3)
        XCTAssertNil(side)
    }

    func testBelowMinimumOutletsIsNotABlindspot() {
        // Lopsided but only 3 outlets total.
        let side = BlindspotFinder.side(leftOutlets: 3, centerOutlets: 0, rightOutlets: 0)
        XCTAssertNil(side)
    }

    func testSmallMinoritySideStillCountsWhenUnderTenPercent() {
        // 12 outlets, right has 1 which is about 8 percent, left dominates.
        let side = BlindspotFinder.side(leftOutlets: 11, centerOutlets: 0, rightOutlets: 1)
        XCTAssertEqual(side, .right)
    }

    func testMinoritySideAboveTenPercentIsNotBlindspot() {
        // Right has 2 of 10, which is 20 percent. Not a blindspot.
        let side = BlindspotFinder.side(leftOutlets: 8, centerOutlets: 0, rightOutlets: 2)
        XCTAssertNil(side)
    }

    func testDominantSideMustHoldMajority() {
        // Left is low, but right only has 40 percent, center holds the rest.
        let side = BlindspotFinder.side(leftOutlets: 0, centerOutlets: 6, rightOutlets: 4)
        XCTAssertNil(side)
    }

    func testLabelText() {
        XCTAssertEqual(BlindspotFinder.label(for: .left), "Blindspot: left")
        XCTAssertEqual(BlindspotFinder.label(for: .right), "Blindspot: right")
    }
}
