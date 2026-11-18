import XCTest
@testable import Page2

final class OPMLServiceTests: XCTestCase {

    func testExportContainsFeedAndBias() {
        let sources = [ImportedSource(name: "Vox", feedURL: "https://vox.com/rss",
                                      siteURL: "https://vox.com", bias: .left, isEnabled: true)]
        let opml = OPMLService.export(sources)
        XCTAssertTrue(opml.contains("<opml version=\"2.0\">"))
        XCTAssertTrue(opml.contains("xmlUrl=\"https://vox.com/rss\""))
        XCTAssertTrue(opml.contains("page2Bias=\"left\""))
        XCTAssertTrue(opml.contains("page2Enabled=\"true\""))
    }

    func testRoundTrip() {
        let sources = [
            ImportedSource(name: "Vox", feedURL: "https://vox.com/rss",
                           siteURL: "https://vox.com", bias: .left, isEnabled: true),
            ImportedSource(name: "Fox News", feedURL: "https://feeds.foxnews.com/foxnews/latest",
                           siteURL: "https://foxnews.com", bias: .right, isEnabled: false)
        ]
        let parsed = OPMLService.parse(OPMLService.export(sources))
        XCTAssertEqual(parsed, sources)
    }

    func testParsesStandardOPMLWithoutPage2Attributes() {
        let opml = """
        <?xml version="1.0"?>
        <opml version="2.0"><body>
        <outline text="Example" type="rss" xmlUrl="https://example.com/feed" htmlUrl="https://example.com"/>
        </body></opml>
        """
        let parsed = OPMLService.parse(opml)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.feedURL, "https://example.com/feed")
        XCTAssertEqual(parsed.first?.bias, .center, "Unknown bias defaults to center")
        XCTAssertEqual(parsed.first?.isEnabled, true, "Missing enabled defaults to true")
    }

    func testSkipsFolderOutlinesWithoutFeed() {
        let opml = """
        <opml version="2.0"><body>
        <outline text="A Folder">
          <outline text="Child Feed" type="rss" xmlUrl="https://a.com/feed"/>
        </outline>
        </body></opml>
        """
        let parsed = OPMLService.parse(opml)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.feedURL, "https://a.com/feed")
    }

    func testEscapesAndDecodesSpecialCharacters() {
        let sources = [ImportedSource(name: "Tom & Jerry \"News\"",
                                      feedURL: "https://x.com/f?q=a&b=c",
                                      siteURL: "", bias: .center, isEnabled: true)]
        let opml = OPMLService.export(sources)
        XCTAssertTrue(opml.contains("&amp;"))
        let parsed = OPMLService.parse(opml)
        XCTAssertEqual(parsed.first?.name, "Tom & Jerry \"News\"")
        XCTAssertEqual(parsed.first?.feedURL, "https://x.com/f?q=a&b=c")
    }
}
