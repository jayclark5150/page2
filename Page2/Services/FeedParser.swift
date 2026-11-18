import Foundation

/// One article parsed from a feed, before it becomes a stored Article.
struct ParsedFeedItem: Equatable {
    var title: String
    var link: String
    var summary: String
    var publishedAt: Date?
}

/// Parses RSS 2.0 and Atom feeds with XMLParser.
/// Handles CDATA, strips HTML from summaries, decodes entities, and reads
/// RFC 822 and ISO 8601 dates. One instance parses one document.
final class FeedParser: NSObject, XMLParserDelegate {

    enum FeedParserError: Error, CustomStringConvertible {
        case malformed(String)
        var description: String {
            switch self {
            case .malformed(let detail): return "Feed could not be parsed: \(detail)"
            }
        }
    }

    private var items: [ParsedFeedItem] = []

    // Per item scratch state. Reset when an item or entry starts.
    private var insideItem = false
    private var text = ""
    private var itemTitle = ""
    private var rssLink = ""
    private var atomLink = ""
    private var descriptionText = ""
    private var summaryText = ""
    private var contentText = ""
    private var primaryDate: Date?
    private var fallbackDate: Date?

    /// Parses the document and returns the items it found.
    func parse(data: Data) throws -> [ParsedFeedItem] {
        items.removeAll()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            let detail = parser.parserError.map { String(describing: $0) } ?? "unknown error"
            throw FeedParserError.malformed(detail)
        }
        return items
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        let name = elementName.lowercased()

        if name == "item" || name == "entry" {
            beginItem()
            return
        }

        if insideItem, name == "link" {
            // Atom links carry the URL in href. Prefer rel="alternate" or no rel.
            if let href = attributeDict["href"] {
                let rel = attributeDict["rel"]?.lowercased()
                if rel == nil || rel == "alternate" || atomLink.isEmpty {
                    atomLink = href
                }
            }
        }

        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard insideItem else { return }
        if let string = String(data: CDATABlock, encoding: .utf8) {
            text += string
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if name == "item" || name == "entry" {
            finishItem()
            text = ""
            return
        }

        guard insideItem else { text = ""; return }

        switch name {
        case "title":
            if itemTitle.isEmpty { itemTitle = Self.clean(trimmed) }
        case "link":
            // RSS puts the URL in element text. Ignore empty Atom link bodies.
            if rssLink.isEmpty, !trimmed.isEmpty { rssLink = trimmed }
        case "description":
            if descriptionText.isEmpty { descriptionText = trimmed }
        case "summary":
            if summaryText.isEmpty { summaryText = trimmed }
        case "content", "content:encoded":
            if contentText.isEmpty { contentText = trimmed }
        case "pubdate", "published", "dc:date", "date":
            if primaryDate == nil { primaryDate = Self.parseDate(trimmed) }
        case "updated", "lastbuilddate":
            if fallbackDate == nil { fallbackDate = Self.parseDate(trimmed) }
        default:
            break
        }

        text = ""
    }

    // MARK: Item lifecycle

    private func beginItem() {
        insideItem = true
        text = ""
        itemTitle = ""
        rssLink = ""
        atomLink = ""
        descriptionText = ""
        summaryText = ""
        contentText = ""
        primaryDate = nil
        fallbackDate = nil
    }

    private func finishItem() {
        let link = rssLink.isEmpty ? atomLink : rssLink
        // Prefer a short summary or description over full content.
        let rawSummary = !summaryText.isEmpty ? summaryText
            : (!descriptionText.isEmpty ? descriptionText : contentText)
        let summary = Self.plainText(from: rawSummary)
        let date = primaryDate ?? fallbackDate

        // An item with neither a link nor a title is not useful. Skip it.
        if !link.isEmpty || !itemTitle.isEmpty {
            items.append(ParsedFeedItem(title: itemTitle,
                                        link: link,
                                        summary: summary,
                                        publishedAt: date))
        }
        insideItem = false
    }

    // MARK: Text cleanup

    /// Collapses whitespace and decodes any leftover entities in a short field.
    static func clean(_ string: String) -> String {
        let decoded = decodeEntities(string)
        return collapseWhitespace(decoded)
    }

    /// Strips HTML tags, decodes entities, and collapses whitespace.
    static func plainText(from html: String) -> String {
        let noTags = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let decoded = decodeEntities(noTags)
        return collapseWhitespace(decoded)
    }

    static func collapseWhitespace(_ string: String) -> String {
        let collapsed = string.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decodes named and numeric HTML entities. Only replaces recognized
    /// patterns, so stray ampersands such as AT&T are left untouched.
    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }

        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": " ", "&mdash;": "-",
            "&ndash;": "-", "&hellip;": "...", "&rsquo;": "'", "&lsquo;": "'",
            "&ldquo;": "\"", "&rdquo;": "\""
        ]

        var result = string
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Numeric entities: decimal &#123; and hex &#x1F600;.
        result = replaceNumericEntities(in: result)
        return result
    }

    private static func replaceNumericEntities(in string: String) -> String {
        guard string.contains("&#") else { return string }
        let pattern = "&#(x?)([0-9A-Fa-f]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }

        let full = string as NSString
        var output = ""
        var lastEnd = 0
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: full.length))

        for match in matches {
            output += full.substring(with: NSRange(location: lastEnd,
                                                   length: match.range.location - lastEnd))
            let isHex = full.substring(with: match.range(at: 1)) == "x"
            let digits = full.substring(with: match.range(at: 2))
            if let value = UInt32(digits, radix: isHex ? 16 : 10),
               let scalar = Unicode.Scalar(value) {
                output += String(scalar)
            } else {
                output += full.substring(with: match.range)
            }
            lastEnd = match.range.location + match.range.length
        }
        output += full.substring(from: lastEnd)
        return output
    }

    // MARK: Dates

    private static let rfc822Formatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm Z"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [withFractional, plain]
    }()

    /// Tries RFC 822 then ISO 8601. Returns nil if nothing matches.
    static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for formatter in rfc822Formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        for formatter in isoFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
