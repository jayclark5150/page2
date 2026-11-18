import SwiftUI

/// Shows one story with its articles grouped under Left, Center, and Right.
/// Each article opens in the default browser through ArticleRow.
struct StoryDetailView: View {
    let story: Story

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.headline).font(.title3.bold())
                    BiasBar(left: story.outletCount(for: .left),
                            center: story.outletCount(for: .center),
                            right: story.outletCount(for: .right),
                            width: 200, height: 10)
                    if let side = BlindspotFinder.side(for: story) {
                        Text(BlindspotFinder.label(for: side))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(side.color)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(Bias.allCases) { bias in
                let articles = articles(for: bias)
                if !articles.isEmpty {
                    Section(bias.label) {
                        ForEach(articles) { ArticleRow(article: $0) }
                    }
                }
            }
        }
        .navigationTitle("Story")
    }

    private func articles(for bias: Bias) -> [Article] {
        story.articles
            .filter { $0.source?.bias == bias }
            .sorted { $0.publishedAt > $1.publishedAt }
    }
}
