import XCTest
@testable import Page2

final class StoryClustererTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_760_000_000)

    private func doc(_ id: String,
                     _ title: String,
                     _ summary: String,
                     slug: String,
                     hoursAfter: Double = 0) -> ClusterDoc<String> {
        ClusterDoc(id: id, title: title, summary: summary, sourceSlug: slug,
                   publishedAt: base.addingTimeInterval(hoursAfter * 3600))
    }

    // Same event, three outlets.
    private var infraDocs: [ClusterDoc<String>] {
        [
            doc("a1", "Senate passes $1.2 trillion infrastructure bill",
                "The Senate approved a major infrastructure spending package on Tuesday.", slug: "guardian"),
            doc("a2", "Infrastructure bill clears Senate in bipartisan vote",
                "Lawmakers passed the trillion dollar infrastructure measure.", slug: "fox", hoursAfter: 2),
            doc("a3", "Senate approves sweeping infrastructure package",
                "The infrastructure bill now heads to the House after Senate passage.", slug: "npr", hoursAfter: 4)
        ]
    }

    // A clearly different event.
    private var hurricaneDocs: [ClusterDoc<String>] {
        [
            doc("b1", "Hurricane strengthens to Category 4 off Florida coast",
                "Forecasters warn of dangerous storm surge as the hurricane nears Florida.", slug: "bbc", hoursAfter: 1),
            doc("b2", "Florida braces for major hurricane landfall",
                "Residents evacuate ahead of the powerful hurricane hitting Florida.", slug: "cbs", hoursAfter: 3)
        ]
    }

    // Unrelated single topics that make the IDF realistic, the way a real
    // refresh brings in many stories at once. Without them a corpus of only
    // near-identical docs neutralizes its own shared terms.
    private var backgroundDocs: [ClusterDoc<String>] {
        [
            doc("c1", "Lakers defeat Celtics in overtime thriller",
                "A late basket sealed the overtime win for the Lakers.", slug: "espn", hoursAfter: 1),
            doc("c2", "Apple unveils new chip at developer conference",
                "The technology company showed off its latest processor.", slug: "verge", hoursAfter: 2),
            doc("c3", "Global coffee prices surge amid drought",
                "A prolonged drought pushed commodity coffee prices higher.", slug: "axios", hoursAfter: 2),
            doc("c4", "Researchers report breakthrough in battery storage",
                "Scientists describe a denser, cheaper battery design.", slug: "pbs", hoursAfter: 3),
            doc("c5", "Broadway revival wins rave reviews",
                "Critics praised the theater revival opening this week.", slug: "slate", hoursAfter: 3)
        ]
    }

    /// Finds the outcome whose attached ids contain the given id.
    private func group(containing id: String,
                       in outcomes: [ClusterOutcome<String>]) -> Set<String>? {
        outcomes.first { $0.addedIDs.contains(id) }.map { Set($0.addedIDs) }
    }

    func testSameEventClustersTogether() {
        let clusterer = StoryClusterer()
        let outcomes = clusterer.cluster(existing: [], incoming: infraDocs + backgroundDocs)

        // The three infrastructure articles should share one story.
        XCTAssertEqual(group(containing: "a1", in: outcomes), ["a1", "a2", "a3"])
        // Each background topic stays on its own.
        XCTAssertEqual(group(containing: "c1", in: outcomes), ["c1"])
    }

    func testUnrelatedStoriesStayApart() {
        let clusterer = StoryClusterer()
        let outcomes = clusterer.cluster(existing: [], incoming: infraDocs + hurricaneDocs + backgroundDocs)

        let infra = group(containing: "a1", in: outcomes)
        let hurricane = group(containing: "b1", in: outcomes)
        XCTAssertEqual(infra, ["a1", "a2", "a3"])
        XCTAssertEqual(hurricane, ["b1", "b2"])
        XCTAssertNotEqual(infra, hurricane, "The two events must not share a story")
        // 3 infra plus 2 hurricane collapse to 2 stories, plus 5 singletons.
        XCTAssertEqual(outcomes.count, 7)
    }

    func testIncrementalJoinToExistingStory() {
        let clusterer = StoryClusterer()
        let existing = [ExistingCluster(storyID: "story-1", members: [infraDocs[0], infraDocs[1]])]
        let outcomes = clusterer.cluster(existing: existing, incoming: [infraDocs[2]])

        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes.first?.existingStoryID, "story-1")
        XCTAssertEqual(outcomes.first?.addedIDs, ["a3"], "Only the new article is attached")
    }

    func testOutsideTimeWindowDoesNotJoin() {
        let clusterer = StoryClusterer()
        // Existing story is 5 days older than the incoming article.
        let old = doc("old", infraDocs[0].title, infraDocs[0].summary, slug: "guardian", hoursAfter: -120)
        let existing = [ExistingCluster(storyID: "story-1", members: [old])]
        let fresh = doc("fresh", infraDocs[1].title, infraDocs[1].summary, slug: "fox", hoursAfter: 0)

        let outcomes = clusterer.cluster(existing: existing, incoming: [fresh])
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertNil(outcomes.first?.existingStoryID, "Too far apart in time to join, so a new story forms")
        XCTAssertEqual(outcomes.first?.addedIDs, ["fresh"])
    }

    func testHeadlineComesFromMostCentralArticle() {
        let clusterer = StoryClusterer()
        let outcomes = clusterer.cluster(existing: [], incoming: infraDocs)
        let headline = outcomes.first?.headline ?? ""
        XCTAssertTrue(infraDocs.map(\.title).contains(headline),
                      "Headline should be one of the member titles")
    }

    func testThresholdEdgeCasesAndReportSimilarities() {
        // Report the cosines we see in a realistic mixed corpus.
        let clusterer = StoryClusterer()
        let corpus = infraDocs + hurricaneDocs + backgroundDocs

        let sameEvent = clusterer.debugCosine(infraDocs[0], infraDocs[1], corpus: corpus)
        let crossEvent = clusterer.debugCosine(infraDocs[0], hurricaneDocs[0], corpus: corpus)
        print("CLUSTER-SIM same-event a1~a2 = \(String(format: "%.3f", sameEvent))")
        print("CLUSTER-SIM cross-event a1~b1 = \(String(format: "%.3f", crossEvent))")

        XCTAssertGreaterThan(sameEvent, 0.35, "Same event pair should clear the default threshold")
        XCTAssertLessThan(crossEvent, 0.35, "Cross event pair should fall below the default threshold")

        // A very high threshold merges nothing: 3 infra plus 2 hurricane stay split.
        let strict = StoryClusterer(settings: ClusterSettings(threshold: 0.99))
        let split = strict.cluster(existing: [], incoming: infraDocs + hurricaneDocs)
        XCTAssertEqual(split.count, 5, "At threshold 0.99 nothing merges")

        // A very low threshold merges anything that shares a term. Infra merges
        // and hurricane merges, but they share no words so stay as two stories.
        let loose = StoryClusterer(settings: ClusterSettings(threshold: 0.01))
        let merged = loose.cluster(existing: [], incoming: infraDocs + hurricaneDocs)
        XCTAssertEqual(merged.count, 2, "Zero overlap keeps the two events apart even at 0.01")
    }
}
