import Foundation

/// A source as it crosses the OPML boundary, independent of SwiftData.
struct ImportedSource: Equatable {
    var name: String
    var feedURL: String
    var siteURL: String
    var bias: Bias
    var isEnabled: Bool
}

/// Reads and writes the source list as OPML 2.0. Feed specific fields use the
/// standard outline attributes; bias and enabled state ride along as custom
/// page2 attributes that other readers safely ignore.
enum OPMLService {

    static func export(_ sources: [ImportedSource]) -> String {
        let created = ISO8601DateFormatter().string(from: Date())
        var lines = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<opml version=\"2.0\">",
            "  <head>",
            "    <title>Page 2 Sources</title>",
            "    <dateCreated>\(created)</dateCreated>",
            "  </head>",
            "  <body>"
        ]
        for source in sources {
            let name = escape(source.name)
            let feed = escape(source.feedURL)
            let site = escape(source.siteURL)
            let bias = source.bias.rawValue
            let enabled = source.isEnabled ? "true" : "false"
            var attrs = "text=\"\(name)\" title=\"\(name)\" type=\"rss\" "
            attrs += "xmlUrl=\"\(feed)\" htmlUrl=\"\(site)\" "
            attrs += "page2Bias=\"\(bias)\" page2Enabled=\"\(enabled)\""
            lines.append("    <outline \(attrs)/>")
        }
        lines.append("  </body>")
        lines.append("</opml>")
        return lines.joined(separator: "\n") + "\n"
    }

    static func parse(_ opml: String) -> [ImportedSource] {
        let delegate = Delegate()
        let parser = XMLParser(data: Data(opml.utf8))
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Collects every outline element that has a feed URL. Outlines without one
    /// (folders in other readers) are skipped.
    private final class Delegate: NSObject, XMLParserDelegate {
        var items: [ImportedSource] = []

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes attributeDict: [String: String]) {
            guard elementName.lowercased() == "outline" else { return }
            guard let feed = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"],
                  !feed.isEmpty else { return }

            let name = attributeDict["text"] ?? attributeDict["title"] ?? feed
            let site = attributeDict["htmlUrl"] ?? attributeDict["htmlurl"] ?? ""
            let bias = Bias(rawValue: attributeDict["page2Bias"] ?? "") ?? .center
            let enabled = (attributeDict["page2Enabled"]).map { $0 == "true" } ?? true

            items.append(ImportedSource(name: name, feedURL: feed, siteURL: site,
                                        bias: bias, isEnabled: enabled))
        }
    }
}
