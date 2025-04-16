import SwiftUI
import WebKit

struct SpotifyWebView: UIViewRepresentable {
    let url: URL
    
    // Required by UIViewRepresentable
    func makeUIView(context: UIViewRepresentableContext<SpotifyWebView>) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    // Required by UIViewRepresentable
    func updateUIView(_ webView: WKWebView, context: UIViewRepresentableContext<SpotifyWebView>) {
        // No updates needed
    }
    
    // Required for coordinator pattern
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator to handle web view navigation
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: SpotifyWebView
        
        init(_ parent: SpotifyWebView) {
            self.parent = parent
        }
        
        // Handle navigation events if needed
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // Handle callback URL if needed
                if url.scheme == "fete" {
                    // Handle the callback
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

// Preview provider for SwiftUI previews
#if DEBUG
struct SpotifyWebView_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyWebView(url: URL(string: "https://accounts.spotify.com")!)
    }
}
#endif 