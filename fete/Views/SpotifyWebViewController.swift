@preconcurrency
import WebKit
import SwiftUI

struct SpotifyWebView: UIViewRepresentable {
    let url: URL
    
    typealias UIViewType = WKWebView
    
    // 1. Define Coordinator
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SpotifyWebView
        
        init(_ parent: SpotifyWebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                if url.scheme == "fete" {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
    
    // 2. Implement required makeCoordinator method
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 3. Fix makeUIView implementation
    func makeUIView(context: UIViewRepresentableContext<SpotifyWebView>) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    // 4. Fix updateUIView implementation
    func updateUIView(_ webView: WKWebView, context: UIViewRepresentableContext<SpotifyWebView>) {
        // No updates needed
    }
}

#if DEBUG
struct SpotifyWebView_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyWebView(url: URL(string: "https://accounts.spotify.com")!)
    }
}
#endif