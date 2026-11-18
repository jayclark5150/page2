import SwiftUI
import SwiftData

/// Clustered stories, newest activity first, with search and a bias filter.
struct StoriesView: View {
    @Query(sort: \Story.updatedAt, order: .reverse) private var stories: [Story]
    @State private var searchText = ""
    @State private var biasFilter: Bias?

    var body: some View {
        NavigationStack {
            Group {
                if stories.isEmpty {
                    ContentUnavailableView(
                        "No stories yet",
                        systemImage: "newspaper",
                        description: Text("Press Refresh or Cmd R to fetch and cluster the news.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filtered) { story in
                            NavigationLink {
                                StoryDetailView(story: story)
                            } label: {
                                StoryRow(story: story)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stories")
            .searchable(text: $searchText, prompt: "Search headlines")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    biasMenu
                }
            }
        }
    }

    private var biasMenu: some View {
        Menu {
            Picker("Bias", selection: $biasFilter) {
                Text("All sides").tag(Bias?.none)
                ForEach(Bias.allCases) { bias in
                    Text(bias.label).tag(Bias?.some(bias))
                }
            }
        } label: {
            Label(biasFilter?.label ?? "All sides", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    /// Applies the bias filter and the search text.
    private var filtered: [Story] {
        stories.filter { story in
            if let bias = biasFilter, story.outletCount(for: bias) == 0 { return false }
            guard !searchText.isEmpty else { return true }
            let needle = searchText.lowercased()
            if story.headline.lowercased().contains(needle) { return true }
            return story.articles.contains { $0.title.lowercased().contains(needle) }
        }
    }
}
