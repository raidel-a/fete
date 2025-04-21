import Foundation
import Combine
import SwiftUI

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingWebView = false
    @Published var authURL: URL?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSpotifyAuthObservers()
    }
    
    private func setupSpotifyAuthObservers() {
        SpotifyAuthManager.shared.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                
                // Check for sp_dc cookie after authentication
                if isAuthenticated {
                    self?.checkSpotifyCookie()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkSpotifyCookie() {
        // Check if we already have the cookie
        if let cookie = KeychainManager.shared.getSpotifyDCCookie() {
            print("✅ Found existing sp_dc cookie: \(String(cookie.prefix(5)))...")
            return
        }
        
        // Check HTTPCookieStorage
        if let spotifyURL = URL(string: "https://open.spotify.com"),
           let cookies = HTTPCookieStorage.shared.cookies(for: spotifyURL) {
            for cookie in cookies {
                if cookie.name == "sp_dc" {
                    print("✅ Found sp_dc cookie in HTTPCookieStorage: \(String(cookie.value.prefix(5)))...")
                    KeychainManager.shared.saveSpotifyDCCookie(cookie.value)
                    return
                }
            }
        }
        
        print("⚠️ No sp_dc cookie found after authentication")
    }
    
    func signInWithSpotify() {
        print("🔄 Starting Spotify authentication")
        if let url = SpotifyAuthManager.shared.authURL {
            print("✅ Got auth URL: \(url)")
            self.authURL = url
            self.showingWebView = true
        } else {
            print("❌ Failed to get auth URL")
        }
    }
} 
