import SwiftUI
import SwiftData

/// Stories with enough coverage where one side barely reported.
struct BlindspotView: View {
    @Query(sort: \Story.updatedAt, order: .reverse) private var stories: [Story]
    private let settings = BlindspotSettings()

    var body: some View {
        NavigationStack {
            Group {
                if blindspots.isEmpty {
                    ContentUnavailableView(
                        "No blindspots",
                        systemImage: "eye.trianglebadge.exclamationmark",
                        description: Text("Stories with at least \(settings.minOutlets) outlets where one side barely reported will show here.")
                    )
                } else {
                    List {
                        ForEach(blindspots, id: \.story.persistentModelID) { item in
                            NavigationLink {
                                StoryDetailView(story: item.story)
                            } label: {
                                StoryRow(story: item.story, blindspotSide: item.side)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Blindspot")
        }
    }

    private var blindspots: [(story: Story, side: Bias)] {
        stories.compactMap { story in
            guard let side = BlindspotFinder.side(for: story, settings: settings) else { return nil }
            return (story, side)
        }
    }
}
