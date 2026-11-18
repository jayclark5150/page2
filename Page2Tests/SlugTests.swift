import XCTest
@testable import Page2

final class SlugTests: XCTestCase {

    func testMakeSlugifies() {
        XCTAssertEqual(Slug.make(from: "AP News"), "ap-news")
        XCTAssertEqual(Slug.make(from: "  The Hill!! "), "the-hill")
        XCTAssertEqual(Slug.make(from: "a--b__c"), "a-b-c")
        XCTAssertEqual(Slug.make(from: "The New York Times"), "the-new-york-times")
    }

    func testMakeFallsBackWhenEmpty() {
        XCTAssertEqual(Slug.make(from: "!!!"), "source")
        XCTAssertEqual(Slug.make(from: ""), "source")
    }

    func testUniqueAppendsSuffix() {
        XCTAssertEqual(Slug.unique("vox", taken: []), "vox")
        XCTAssertEqual(Slug.unique("vox", taken: ["vox"]), "vox-2")
        XCTAssertEqual(Slug.unique("vox", taken: ["vox", "vox-2"]), "vox-3")
    }
}
