import SwiftUI
import SwiftData

/// Milestone 1 version: a flat list of recent articles, newest first.
/// Milestone 2 replaces this with clustered stories.
struct StoriesView: View {
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]

    var body: some View {
        Group {
            if articles.isEmpty {
                ContentUnavailableView(
                    "No articles yet",
                    systemImage: "newspaper",
                    description: Text("Press Refresh or Cmd R to fetch from your enabled sources.")
                )
            } else {
                List(articles) { article in
                    ArticleRow(article: article)
                }
            }
        }
        .navigationTitle("Stories")
    }
}
