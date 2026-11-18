import Foundation
import SwiftData

@Model
final class Article {
    /// The article link doubles as the unique key, so refetching never duplicates.
    @Attribute(.unique) var link: String
    var title: String
    var summary: String
    var publishedAt: Date
    var fetchedAt: Date

    var source: Source?
    var story: Story?

    init(link: String,
         title: String,
         summary: String,
         publishedAt: Date,
         fetchedAt: Date = .now,
         source: Source? = nil) {
        self.link = link
        self.title = title
        self.summary = summary
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.source = source
    }

    var url: URL? { URL(string: link) }
}
