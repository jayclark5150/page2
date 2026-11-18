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
    private let clusterer: StoryClusterer
    /// How far back to pull stories and articles when clustering. Wider than the
    /// 72 hour join window so articles can still find a slightly older story.
    private let clusterLookback: TimeInterval = 5 * 24 * 60 * 60

    init(fetcher: FeedFetcher = FeedFetcher(),
         clusterer: StoryClusterer = StoryClusterer()) {
        self.fetcher = fetcher
        self.clusterer = clusterer
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
        await clusterUnassignedArticles(in: context)
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

    // MARK: Clustering

    /// Assigns articles that have no story yet, either into an existing story or
    /// a new one. The TF-IDF math runs off the main actor on value snapshots.
    private func clusterUnassignedArticles(in context: ModelContext) async {
        let cutoff = Date().addingTimeInterval(-clusterLookback)

        let incomingArticles: [Article]
        let recentStories: [Story]
        do {
            incomingArticles = try context.fetch(FetchDescriptor<Article>(
                predicate: #Predicate { $0.story == nil && $0.publishedAt > cutoff }
            ))
            recentStories = try context.fetch(FetchDescriptor<Story>(
                predicate: #Predicate { $0.updatedAt > cutoff }
            ))
        } catch {
            lastError = "Could not load articles for clustering: \(error)"
            return
        }
        guard !incomingArticles.isEmpty else { return }

        // Snapshots keep SwiftData models off the background task.
        let incoming = incomingArticles.map(snapshot(of:))
        let existing = recentStories.map { story in
            ExistingCluster(storyID: story.persistentModelID,
                            members: story.articles.map(snapshot(of:)))
        }

        // Look up tables to apply the result on the main actor.
        var articleByID: [PersistentIdentifier: Article] = [:]
        for article in incomingArticles { articleByID[article.persistentModelID] = article }
        var storyByID: [PersistentIdentifier: Story] = [:]
        for story in recentStories { storyByID[story.persistentModelID] = story }

        let clusterer = self.clusterer
        let outcomes = await Task.detached(priority: .userInitiated) {
            clusterer.cluster(existing: existing, incoming: incoming)
        }.value

        apply(outcomes, articleByID: articleByID, storyByID: storyByID, in: context)
    }

    private func snapshot(of article: Article) -> ClusterDoc<PersistentIdentifier> {
        ClusterDoc(id: article.persistentModelID,
                   title: article.title,
                   summary: article.summary,
                   sourceSlug: article.source?.slug ?? "",
                   publishedAt: article.publishedAt)
    }

    private func apply(_ outcomes: [ClusterOutcome<PersistentIdentifier>],
                       articleByID: [PersistentIdentifier: Article],
                       storyByID: [PersistentIdentifier: Story],
                       in context: ModelContext) {
        let now = Date()
        for outcome in outcomes {
            let story: Story
            if let id = outcome.existingStoryID, let existing = storyByID[id] {
                story = existing
            } else {
                story = Story(headline: outcome.headline)
                context.insert(story)
            }
            story.headline = outcome.headline
            for articleID in outcome.addedIDs {
                articleByID[articleID]?.story = story
            }
            story.updatedAt = now
        }

        do {
            if context.hasChanges { try context.save() }
        } catch {
            lastError = "Could not save stories: \(error)"
        }
    }
}
