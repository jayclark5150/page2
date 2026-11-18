import Foundation
import SwiftData

/// One outlet as described in Resources/sources.json.
/// This is a plain decodable mirror of the curated list, not the stored model.
struct SourceSeed: Codable {
    let slug: String
    let name: String
    let feedURL: String
    let siteURL: String
    let bias: String
    let verified: Bool?
    let note: String?

    var resolvedBias: Bias { Bias(rawValue: bias) ?? .center }
}

struct SourceSeedFile: Codable {
    let schemaVersion: Int
    let sources: [SourceSeed]
}

enum SourceSeederError: Error, CustomStringConvertible {
    case missingResource
    case decodeFailed(String)

    var description: String {
        switch self {
        case .missingResource:
            return "sources.json was not found in the app bundle. Confirm it is a bundle resource."
        case .decodeFailed(let detail):
            return "sources.json could not be decoded: \(detail)"
        }
    }
}

/// Loads the curated outlet list and inserts or updates Source records by slug.
/// A user's isEnabled choice is never overwritten once a Source exists.
struct SourceSeeder {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Reads and decodes the bundled list. Separated out so tests can call it directly.
    func loadSeeds() throws -> [SourceSeed] {
        guard let url = bundle.url(forResource: "sources", withExtension: "json") else {
            throw SourceSeederError.missingResource
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(SourceSeedFile.self, from: data)
            return file.sources
        } catch {
            throw SourceSeederError.decodeFailed(String(describing: error))
        }
    }

    /// Upserts every seed into the context. Returns counts for logging.
    @discardableResult
    func seed(into context: ModelContext) throws -> (inserted: Int, updated: Int) {
        let seeds = try loadSeeds()
        var inserted = 0
        var updated = 0

        for seed in seeds {
            let slug = seed.slug
            var descriptor = FetchDescriptor<Source>(predicate: #Predicate { $0.slug == slug })
            descriptor.fetchLimit = 1
            let existing = try context.fetch(descriptor).first

            if let source = existing {
                // Leave user owned records alone: never touch an outlet the user
                // added, and never resurrect or edit one the user removed.
                if source.isUserAdded || source.isDeleted { continue }
                // Update curated fields, but leave isEnabled and lastFetchedAt alone.
                source.name = seed.name
                source.feedURLString = seed.feedURL
                source.siteURLString = seed.siteURL
                source.bias = seed.resolvedBias
                updated += 1
            } else {
                let source = Source(
                    slug: seed.slug,
                    name: seed.name,
                    feedURLString: seed.feedURL,
                    siteURLString: seed.siteURL,
                    bias: seed.resolvedBias
                )
                context.insert(source)
                inserted += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }
        return (inserted, updated)
    }
}
