@preconcurrency
import WebKit
import SwiftUI

struct SpotifyWebView: UIViewRepresentable {
    let url: URL
    
    typealias UIViewType = WKWebView
    
    // 1. Define Coordinator
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SpotifyWebView
        private var cookieObserver: CookieObserver?
        
        init(_ parent: SpotifyWebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                if url.scheme == "fete" {
                    // Extract the authorization code from the URL
                    if let code = URLComponents(url: url, resolvingAgainstBaseURL: true)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?
                        .value {
                        print("✅ Got authorization code from callback")
                        
                        // Handle the authorization code
                        Task {
                            do {
                                // Exchange the code for tokens
                                try await SpotifyAuthManager.shared.exchangeCodeForToken(code)
                                
                                // Update authentication state
                                await MainActor.run {
                                    SpotifyAuthManager.shared.isAuthenticated = true
                                }
                            } catch {
                                print("❌ Error exchanging code for token: \(error)")
                            }
                        }
                    }
                    
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Check for cookies after page load
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                print("🍪 Found \(cookies.count) cookies after page load")
                for cookie in cookies {
                    if cookie.name == "sp_dc" {
                        print("✅ Found sp_dc cookie after page load: \(String(cookie.value.prefix(5)))...")
                        KeychainManager.shared.saveSpotifyDCCookie(cookie.value)
                        
                        // Also store in HTTPCookieStorage
                        HTTPCookieStorage.shared.setCookie(cookie)
                    }
                }
            }
        }
        
        // Setup cookie observer
        func setupCookieObserver(for webView: WKWebView) {
            cookieObserver = CookieObserver()
            webView.configuration.websiteDataStore.httpCookieStore.add(cookieObserver!)
        }
        
        deinit {
            if let observer = cookieObserver {
                WKWebsiteDataStore.default().httpCookieStore.remove(observer)
            }
        }
    }
    
    // 2. Implement required makeCoordinator method
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 3. Fix makeUIView implementation
    func makeUIView(context: UIViewRepresentableContext<SpotifyWebView>) -> WKWebView {
        // Configure WKWebView to handle cookies
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Setup cookie observer through coordinator
        context.coordinator.setupCookieObserver(for: webView)
        
        // Load request with cookie handling
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = true
        webView.load(request)
        
        return webView
    }
    
    // 4. Fix updateUIView implementation
    func updateUIView(_ webView: WKWebView, context: UIViewRepresentableContext<SpotifyWebView>) {
        // No updates needed
    }
}

// Cookie observer to monitor cookie changes
class CookieObserver: NSObject, WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { cookies in
            print("🍪 Cookies changed, found \(cookies.count) cookies")
            for cookie in cookies {
                if cookie.name == "sp_dc" {
                    print("✅ Found sp_dc cookie in observer: \(String(cookie.value.prefix(5)))...")
                    KeychainManager.shared.saveSpotifyDCCookie(cookie.value)
                    
                    // Also store in HTTPCookieStorage
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
    }
}

#if DEBUG
struct SpotifyWebView_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyWebView(url: URL(string: "https://accounts.spotify.com")!)
    }
}
#endif