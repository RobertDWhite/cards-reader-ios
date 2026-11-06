import SwiftUI
import WebKit

/// The live site, for the collages: they are laid out in the browser by
/// collage.js, and ★ Save writes back to the pages server from the page itself.
struct WebSiteView: View {
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            WebView(url: Server.base, reloadToken: reloadToken)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Collages")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { reloadToken += 1 } label: { Image(systemName: "arrow.clockwise") }
                    }
                }
        }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL
    let reloadToken: Int

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pull(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = refresh
        context.coordinator.webView = wv
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastToken != reloadToken {
            context.coordinator.lastToken = reloadToken
            wv.reload()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(token: reloadToken) }

    final class Coordinator: NSObject {
        weak var webView: WKWebView?
        var lastToken: Int
        init(token: Int) { lastToken = token }

        @objc func pull(_ rc: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { rc.endRefreshing() }
        }
    }
}
