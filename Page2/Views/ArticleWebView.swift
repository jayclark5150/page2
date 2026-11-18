import SwiftUI

/// Reads an article inside the app. Keeps an Open in Browser escape hatch.
struct ArticleWebView: View {
    let article: Article
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let url = article.url {
                WebView(url: url)
            } else {
                ContentUnavailableView("No link", systemImage: "link.badge.plus")
            }
        }
        .navigationTitle(article.source?.name ?? "Article")
        .toolbar {
            if let url = article.url {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    .help("Open this article in the default browser")
                }
            }
        }
    }
}
