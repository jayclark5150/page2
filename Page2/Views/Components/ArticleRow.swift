import SwiftUI

/// One article in a list. Shows the outlet, a bias chip, the headline, a short
/// summary, and the published time. Tapping opens the article inside the app.
struct ArticleRow: View {
    let article: Article

    var body: some View {
        NavigationLink {
            ArticleWebView(article: article)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let source = article.source {
                        Text(source.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        BiasChip(bias: source.bias)
                    }
                    Spacer()
                    Text(article.publishedAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(article.title.isEmpty ? article.link : article.title)
                    .font(.headline)
                    .lineLimit(2)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
