import Foundation

/// Tunable clustering constants in one place.
struct ClusterSettings: Sendable {
    /// Cosine similarity an article must clear to join a story.
    var threshold: Double = 0.35
    /// Title tokens count this many times versus summary tokens.
    var titleWeight: Int = 2
    /// Only compare articles published within this many hours of each other.
    var windowHours: Double = 72
}

/// One article as seen by the clusterer, independent of SwiftData.
struct ClusterDoc<ID: Hashable & Sendable>: Sendable {
    let id: ID
    let title: String
    let summary: String
    let sourceSlug: String
    let publishedAt: Date
}

/// An existing story and its current member articles.
struct ExistingCluster<ID: Hashable & Sendable>: Sendable {
    let storyID: ID
    let members: [ClusterDoc<ID>]
}

/// What to change after clustering. existingStoryID nil means create a new story.
/// addedIDs are the articles to attach: all members for a new story, only the
/// newly joined ones for an existing story.
struct ClusterOutcome<ID: Hashable & Sendable>: Sendable {
    let existingStoryID: ID?
    let addedIDs: [ID]
    let headline: String
}

/// Incremental TF-IDF clusterer. New articles join the most similar existing
/// story above the threshold, or start a new story. IDF is computed over the
/// working set each run so vectors share one space.
struct StoryClusterer: Sendable {
    var settings: ClusterSettings
    var tokenizer: Tokenizer

    init(settings: ClusterSettings = ClusterSettings(), tokenizer: Tokenizer = Tokenizer()) {
        self.settings = settings
        self.tokenizer = tokenizer
    }

    func cluster<ID>(existing: [ExistingCluster<ID>],
                     incoming: [ClusterDoc<ID>]) -> [ClusterOutcome<ID>] {
        guard !incoming.isEmpty else { return [] }

        let everyDoc = existing.flatMap(\.members) + incoming
        let idf = computeIDF(everyDoc)

        var clusters: [Working<ID>] = existing.map { ec in
            let scored = ec.members.map { ($0, vector($0, idf)) }
            return Working(storyID: ec.storyID,
                           members: scored.map { MemberVec(id: $0.0.id, title: $0.0.title, vector: $0.1) },
                           latestDate: ec.members.map(\.publishedAt).max() ?? .distantPast)
        }

        let windowSeconds = settings.windowHours * 3600
        for doc in incoming.sorted(by: { $0.publishedAt < $1.publishedAt }) {
            let v = vector(doc, idf)

            var best: Working<ID>?
            var bestSim = -1.0
            for cluster in clusters {
                guard abs(doc.publishedAt.timeIntervalSince(cluster.latestDate)) <= windowSeconds else { continue }
                let sim = Self.cosine(v, cluster.centroid)
                if sim >= settings.threshold, sim > bestSim {
                    bestSim = sim
                    best = cluster
                }
            }

            if let best {
                best.add(MemberVec(id: doc.id, title: doc.title, vector: v), date: doc.publishedAt)
            } else {
                let fresh = Working(storyID: nil as ID?,
                                    members: [MemberVec(id: doc.id, title: doc.title, vector: v)],
                                    latestDate: doc.publishedAt)
                fresh.addedIDs = [doc.id]
                clusters.append(fresh)
            }
        }

        return clusters.compactMap { cluster in
            let isNew = cluster.storyID == nil
            guard isNew || !cluster.addedIDs.isEmpty else { return nil }
            return ClusterOutcome(existingStoryID: cluster.storyID,
                                  addedIDs: cluster.addedIDs,
                                  headline: cluster.headline())
        }
    }

    /// Cosine similarity of two docs in the IDF space of a given corpus.
    /// Used by tests to report the numbers behind clustering decisions.
    func debugCosine<ID>(_ a: ClusterDoc<ID>, _ b: ClusterDoc<ID>,
                         corpus: [ClusterDoc<ID>]) -> Double {
        let idf = computeIDF(corpus)
        return Self.cosine(vector(a, idf), vector(b, idf))
    }

    // MARK: TF-IDF

    /// Raw term counts with the title weighted. Tokenized once, then scaled.
    func termCounts(title: String, summary: String) -> [String: Double] {
        var counts: [String: Double] = [:]
        for token in tokenizer.tokens(title) {
            counts[token, default: 0] += Double(settings.titleWeight)
        }
        for token in tokenizer.tokens(summary) {
            counts[token, default: 0] += 1
        }
        return counts
    }

    private func computeIDF<ID>(_ docs: [ClusterDoc<ID>]) -> [String: Double] {
        let total = docs.count
        var documentFrequency: [String: Int] = [:]
        for doc in docs {
            let terms = Set(termCounts(title: doc.title, summary: doc.summary).keys)
            for term in terms { documentFrequency[term, default: 0] += 1 }
        }
        var idf: [String: Double] = [:]
        for (term, df) in documentFrequency {
            idf[term] = log(Double(total + 1) / Double(df + 1)) + 1
        }
        return idf
    }

    private func vector<ID>(_ doc: ClusterDoc<ID>, _ idf: [String: Double]) -> [String: Double] {
        var vector: [String: Double] = [:]
        for (term, tf) in termCounts(title: doc.title, summary: doc.summary) {
            if let weight = idf[term] { vector[term] = tf * weight }
        }
        return vector
    }

    static func cosine(_ a: [String: Double], _ b: [String: Double]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let (small, large) = a.count <= b.count ? (a, b) : (b, a)
        var dot = 0.0
        for (term, value) in small where large[term] != nil {
            dot += value * (large[term] ?? 0)
        }
        guard dot != 0 else { return 0 }
        let normA = sqrt(a.values.reduce(0) { $0 + $1 * $1 })
        let normB = sqrt(b.values.reduce(0) { $0 + $1 * $1 })
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }

    static func centroid(_ vectors: [[String: Double]]) -> [String: Double] {
        guard !vectors.isEmpty else { return [:] }
        var sum: [String: Double] = [:]
        for vector in vectors {
            for (term, value) in vector { sum[term, default: 0] += value }
        }
        let count = Double(vectors.count)
        for term in sum.keys { sum[term] = (sum[term] ?? 0) / count }
        return sum
    }
}

// MARK: - Working cluster

private struct MemberVec<ID: Hashable & Sendable> {
    let id: ID
    let title: String
    let vector: [String: Double]
}

/// Mutable cluster used only during a clustering run.
private final class Working<ID: Hashable & Sendable> {
    let storyID: ID?
    var members: [MemberVec<ID>]
    var addedIDs: [ID] = []
    var latestDate: Date
    private(set) var centroid: [String: Double]

    init(storyID: ID?, members: [MemberVec<ID>], latestDate: Date) {
        self.storyID = storyID
        self.members = members
        self.latestDate = latestDate
        self.centroid = StoryClusterer.centroid(members.map(\.vector))
    }

    func add(_ member: MemberVec<ID>, date: Date) {
        members.append(member)
        addedIDs.append(member.id)
        if date > latestDate { latestDate = date }
        centroid = StoryClusterer.centroid(members.map(\.vector))
    }

    /// The title of the member closest to the centroid.
    func headline() -> String {
        var bestTitle = members.first?.title ?? ""
        var bestSim = -1.0
        for member in members {
            let sim = StoryClusterer.cosine(member.vector, centroid)
            if sim > bestSim {
                bestSim = sim
                bestTitle = member.title
            }
        }
        return bestTitle
    }
}
