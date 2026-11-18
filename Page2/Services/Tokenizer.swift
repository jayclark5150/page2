import Foundation

/// Turns text into comparable tokens for clustering.
///
/// Design choice: no stemming in v1. News clustering leans hardest on proper
/// nouns (names, places, organizations), and crude suffix stemming mangles
/// those more often than it helps (for example "Harris" to "Harri"). TF-IDF
/// already downweights common word variants, so the added error is not worth
/// it. Revisit with a real stemmer if recall looks low.
struct Tokenizer: Sendable {

    /// Common English words that carry little signal for matching stories.
    static let stopwords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
        "had", "her", "was", "one", "our", "out", "day", "get", "has", "him",
        "his", "how", "man", "new", "now", "old", "see", "two", "way", "who",
        "boy", "did", "its", "let", "put", "say", "she", "too", "use", "that",
        "this", "with", "have", "from", "they", "will", "would", "there",
        "their", "what", "about", "which", "when", "make", "like", "time",
        "just", "them", "than", "then", "some", "into", "over", "also", "after",
        "more", "most", "other", "such", "only", "your", "could", "should",
        "been", "were", "says", "said", "amid", "amp", "via"
    ]

    /// Lowercases, splits on anything that is not a letter or digit, drops
    /// stopwords and single character tokens. Numbers of two or more digits,
    /// such as years, are kept because they help date specific events.
    func tokens(_ text: String) -> [String] {
        let lowered = text.lowercased()
        let parts = lowered.split { !$0.isLetter && !$0.isNumber }
        return parts.compactMap { part in
            let token = String(part)
            guard token.count >= 2, !Self.stopwords.contains(token) else { return nil }
            return token
        }
    }
}
