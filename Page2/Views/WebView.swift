import SwiftUI
import WebKit

/// A WKWebView wrapped for SwiftUI on both macOS and iOS. Loads a URL once and
/// reloads only when the requested URL changes, so in page navigation is kept.
struct WebView {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    fileprivate func makeWebView(_ coordinator: Coordinator) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        coordinator.load(url, in: webView)
        return webView
    }

    final class Coordinator {
        private var loaded: URL?

        func load(_ url: URL, in webView: WKWebView) {
            guard loaded != url else { return }
            loaded = url
            webView.load(URLRequest(url: url))
        }
    }
}

#if os(macOS)
extension WebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url, in: webView)
    }
}
#else
extension WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url, in: webView)
    }
}
#endif
