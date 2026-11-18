import XCTest
@testable import Page2

final class FeedParserTests: XCTestCase {

    // MARK: RSS 2.0

    func testParsesRSSItems() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Test Feed</title>
            <item>
              <title>First &amp; Big Story</title>
              <link>https://example.com/a</link>
              <description><![CDATA[<p>Hello <b>world</b> &amp; more</p>]]></description>
              <pubDate>Wed, 12 Nov 2026 08:30:00 +0000</pubDate>
            </item>
            <item>
              <title>Second Story</title>
              <link>https://example.com/b</link>
              <description>Plain text summary</description>
              <pubDate>Tue, 11 Nov 2026 10:00:00 GMT</pubDate>
            </item>
          </channel>
        </rss>
        """
        let items = try FeedParser().parse(data: Data(xml.utf8))

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "First & Big Story")
        XCTAssertEqual(items[0].link, "https://example.com/a")
        XCTAssertEqual(items[0].summary, "Hello world & more")
        XCTAssertEqual(items[1].link, "https://example.com/b")
        XCTAssertEqual(items[1].summary, "Plain text summary")

        let date = try XCTUnwrap(items[0].publishedAt)
        let parts = utcComponents(date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 11)
        XCTAssertEqual(parts.day, 12)
        XCTAssertEqual(parts.hour, 8)
        XCTAssertEqual(parts.minute, 30)
    }

    // MARK: Atom

    func testParsesAtomEntries() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Atom Test</title>
          <entry>
            <title>Atom Entry One</title>
            <link rel="alternate" href="https://example.com/atom1"/>
            <summary>Summary with &lt;b&gt;markup&lt;/b&gt;</summary>
            <published>2026-11-12T08:30:00Z</published>
          </entry>
        </feed>
        """
        let items = try FeedParser().parse(data: Data(xml.utf8))

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Atom Entry One")
        XCTAssertEqual(items[0].link, "https://example.com/atom1")
        XCTAssertEqual(items[0].summary, "Summary with markup")
        XCTAssertNotNil(items[0].publishedAt)
    }

    func testAtomPrefersAlternateLink() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>Multi Link</title>
            <link rel="self" href="https://example.com/self"/>
            <link rel="alternate" href="https://example.com/real"/>
            <published>2026-11-12T08:30:00Z</published>
          </entry>
        </feed>
        """
        let items = try FeedParser().parse(data: Data(xml.utf8))
        XCTAssertEqual(items.first?.link, "https://example.com/real")
    }

    // MARK: Text cleanup

    func testPlainTextStripsTagsAndDecodesEntities() {
        let input = "<p>Tom &amp; Jerry&#39;s &#x201C;day&#x201D;</p>"
        XCTAssertEqual(FeedParser.plainText(from: input), "Tom & Jerry's \u{201C}day\u{201D}")
    }

    func testPlainTextLeavesStrayAmpersand() {
        XCTAssertEqual(FeedParser.plainText(from: "AT&T merger"), "AT&T merger")
    }

    // MARK: Dates

    func testParsesRFC822AndISO8601() {
        XCTAssertNotNil(FeedParser.parseDate("Wed, 12 Nov 2026 08:30:00 +0000"))
        XCTAssertNotNil(FeedParser.parseDate("Tue, 11 Nov 2026 10:00:00 GMT"))
        XCTAssertNotNil(FeedParser.parseDate("2026-11-12T08:30:00Z"))
        XCTAssertNotNil(FeedParser.parseDate("2026-11-12T08:30:00.123Z"))
        XCTAssertNil(FeedParser.parseDate("not a date"))
        XCTAssertNil(FeedParser.parseDate(""))
    }

    // MARK: Helpers

    private func utcComponents(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }
}
