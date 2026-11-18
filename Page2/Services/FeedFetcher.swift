import Foundation

extension ParsedFeedItem: @unchecked Sendable {}

/// A Sendable snapshot of a Source, so network work never touches SwiftData models.
struct FeedSourceRef: Sendable, Hashable {
    let slug: String
    let feedURL: URL
}

/// The outcome of fetching one source. Either items or an error string, never both empty by design.
struct FeedFetchResult: Sendable {
    let slug: String
    let items: [ParsedFeedItem]
    let error: String?
}

/// Fetches and parses many feeds concurrently with a bounded number in flight.
/// Dedupes by link within a feed and drops items older than the age limit.
struct FeedFetcher {
    var session: URLSession
    var maxConcurrent: Int
    var timeout: TimeInterval
    var maxAge: TimeInterval
    var now: () -> Date

    init(session: URLSession = .shared,
         maxConcurrent: Int = 6,
         timeout: TimeInterval = 15,
         maxAgeDays: Int = 7,
         now: @escaping () -> Date = Date.init) {
        self.session = session
        self.maxConcurrent = max(1, maxConcurrent)
        self.timeout = timeout
        self.maxAge = TimeInterval(maxAgeDays) * 24 * 60 * 60
        self.now = now
    }

    func fetchAll(_ refs: [FeedSourceRef]) async -> [FeedFetchResult] {
        guard !refs.isEmpty else { return [] }
        var results: [FeedFetchResult] = []
        results.reserveCapacity(refs.count)

        await withTaskGroup(of: FeedFetchResult.self) { group in
            var iterator = refs.makeIterator()
            var started = 0

            // Prime the group up to the concurrency limit.
            while started < maxConcurrent, let ref = iterator.next() {
                group.addTask { await fetchOne(ref) }
                started += 1
            }

            // Each time one finishes, start the next.
            while let result = await group.next() {
                results.append(result)
                if let ref = iterator.next() {
                    group.addTask { await fetchOne(ref) }
                }
            }
        }

        return results
    }

    private func fetchOne(_ ref: FeedSourceRef) async -> FeedFetchResult {
        var request = URLRequest(url: ref.feedURL)
        request.timeoutInterval = timeout
        request.setValue("Page2/0.1 (personal news reader)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml",
                         forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return FeedFetchResult(slug: ref.slug, items: [],
                                       error: "HTTP \(http.statusCode)")
            }
            let parsed = try FeedParser().parse(data: data)
            let cleaned = filterAndDedupe(parsed)
            return FeedFetchResult(slug: ref.slug, items: cleaned, error: nil)
        } catch {
            return FeedFetchResult(slug: ref.slug, items: [], error: String(describing: error))
        }
    }

    /// Drops items with an empty link, items older than the age limit, and
    /// duplicate links, keeping the first occurrence. Items with no date are kept.
    private func filterAndDedupe(_ items: [ParsedFeedItem]) -> [ParsedFeedItem] {
        let cutoff = now().addingTimeInterval(-maxAge)
        var seen = Set<String>()
        var result: [ParsedFeedItem] = []

        for item in items {
            guard !item.link.isEmpty else { continue }
            if let published = item.publishedAt, published < cutoff { continue }
            guard seen.insert(item.link).inserted else { continue }
            result.append(item)
        }
        return result
    }
}
