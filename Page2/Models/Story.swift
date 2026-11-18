import Foundation
import SwiftData

@Model
final class Story {
    @Attribute(.unique) var id: UUID
    var headline: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Article.story)
    var articles: [Article] = []

    init(headline: String, createdAt: Date = .now) {
        self.id = UUID()
        self.headline = headline
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Number of distinct outlets covering this story with the given bias.
    func outletCount(for bias: Bias) -> Int {
        let slugs = articles.compactMap { article -> String? in
            guard let source = article.source, source.bias == bias else { return nil }
            return source.slug
        }
        return Set(slugs).count
    }

    var totalOutletCount: Int {
        Set(articles.compactMap { $0.source?.slug }).count
    }
}
