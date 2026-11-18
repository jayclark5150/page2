import Foundation

/// Checks that a URL points at a reachable RSS or Atom feed, for the Add Source form.
enum FeedValidator {

    enum Status: Equatable {
        case idle
        case checking
        case valid(articleCount: Int)
        case invalid(String)
    }

    static func check(_ urlString: String,
                      session: URLSession = .shared) async -> Status {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .invalid("Enter a valid http or https URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Page2/0.2 (feed check)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml",
                         forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return .invalid("Server returned HTTP \(http.statusCode)")
            }
            let items = try FeedParser().parse(data: data)
            if items.isEmpty {
                return .invalid("No articles found. Is this an RSS or Atom feed?")
            }
            return .valid(articleCount: items.count)
        } catch {
            return .invalid("Could not load the feed")
        }
    }
}
