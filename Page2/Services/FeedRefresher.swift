import Foundation
import SwiftData
import Observation

/// Drives a refresh: snapshot enabled sources, fetch and parse off the context,
/// then upsert articles by link on the main actor. Clustering is added in a later
/// milestone and will run after the save.
@MainActor
@Observable
final class FeedRefresher {
    var isRefreshing = false
    var lastRefreshedAt: Date?
    /// Per source error messages from the most recent refresh, keyed by slug.
    var sourceErrors: [String: String] = [:]
    /// A top level message for failures that stop the whole refresh.
    var lastError: String?

    private let fetcher: FeedFetcher

    init(fetcher: FeedFetcher = FeedFetcher()) {
        self.fetcher = fetcher
    }

    func refresh(context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        let refs: [FeedSourceRef]
        do {
            refs = try enabledSourceRefs(in: context)
        } catch {
            lastError = "Could not load sources: \(error)"
            return
        }

        guard !refs.isEmpty else {
            lastRefreshedAt = Date()
            return
        }

        // Network and parsing happen here, away from the context.
        let results = await fetcher.fetchAll(refs)

        persist(results, in: context)
        lastRefreshedAt = Date()
    }

    private func enabledSourceRefs(in context: ModelContext) throws -> [FeedSourceRef] {
        let descriptor = FetchDescriptor<Source>(predicate: #Predicate { $0.isEnabled })
        let sources = try context.fetch(descriptor)
        return sources.compactMap { source in
            guard let url = source.feedURL else { return nil }
            return FeedSourceRef(slug: source.slug, feedURL: url)
        }
    }

    private func persist(_ results: [FeedFetchResult], in context: ModelContext) {
        var errors: [String: String] = [:]

        for result in results {
            if let error = result.error {
                errors[result.slug] = error
                continue
            }
            guard let source = source(withSlug: result.slug, in: context) else { continue }

            for item in result.items {
                upsertArticle(item, source: source, in: context)
            }
            source.lastFetchedAt = Date()
        }

        sourceErrors = errors

        do {
            if context.hasChanges { try context.save() }
        } catch {
            lastError = "Could not save articles: \(error)"
        }
    }

    private func upsertArticle(_ item: ParsedFeedItem, source: Source, in context: ModelContext) {
        let link = item.link
        var descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.link == link })
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor))?.first

        if let article = existing {
            // Refresh text in case the outlet edited the headline or summary.
            article.title = item.title
            article.summary = item.summary
            if let published = item.publishedAt { article.publishedAt = published }
            if article.source == nil { article.source = source }
        } else {
            let article = Article(
                link: link,
                title: item.title,
                summary: item.summary,
                publishedAt: item.publishedAt ?? Date(),
                source: source
            )
            context.insert(article)
        }
    }

    private func source(withSlug slug: String, in context: ModelContext) -> Source? {
        var descriptor = FetchDescriptor<Source>(predicate: #Predicate { $0.slug == slug })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
