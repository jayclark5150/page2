import Foundation
import SwiftData

@Model
final class Source {
    /// Stable slug from the curated JSON list, for example "example-times".
    @Attribute(.unique) var slug: String
    var name: String
    var feedURLString: String
    var siteURLString: String
    /// Stored as a raw string so SwiftData predicates stay simple.
    var biasRaw: String
    var isEnabled: Bool
    var lastFetchedAt: Date?
    /// True for outlets the user added in the app. The JSON seeder never touches these.
    var isUserAdded: Bool = false
    /// True once the user edits a seeded outlet (for example its bias), so the
    /// seeder stops overwriting their choice on the next launch.
    var isUserEdited: Bool = false
    /// Soft delete tombstone. Hidden from the UI and skipped on fetch, and it
    /// stops the seeder from resurrecting an outlet the user removed.
    var isDeleted: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Article.source)
    var articles: [Article] = []

    init(slug: String,
         name: String,
         feedURLString: String,
         siteURLString: String = "",
         bias: Bias,
         isEnabled: Bool = true,
         isUserAdded: Bool = false) {
        self.slug = slug
        self.name = name
        self.feedURLString = feedURLString
        self.siteURLString = siteURLString
        self.biasRaw = bias.rawValue
        self.isEnabled = isEnabled
        self.isUserAdded = isUserAdded
    }

    var bias: Bias {
        get { Bias(rawValue: biasRaw) ?? .center }
        set { biasRaw = newValue.rawValue }
    }

    var feedURL: URL? { URL(string: feedURLString) }
}
