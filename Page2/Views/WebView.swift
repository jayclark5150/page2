import SwiftUI
import WebKit

/// A WKWebView wrapped for SwiftUI. Loads a URL once and reloads only when the
/// requested URL changes, so in page navigation is not interrupted.
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url, in: webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var loaded: URL?

        func load(_ url: URL, in webView: WKWebView) {
            guard loaded != url else { return }
            loaded = url
            webView.load(URLRequest(url: url))
        }
    }
}
