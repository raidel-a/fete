import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
class SpotifyAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    // MARK: - Properties
    static let shared = SpotifyAuthManager()
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var tokenExpirationDate: Date?
    
    // Replace these with your Spotify API credentials
    private let clientID = "82ad3bc71f484f5ab969c3f470cbbdcd"
    private let clientSecret = "1b8f7f60a1bc46f9ab970a9ffd843b30"
    private let redirectURI = "fete://callback"
    
    private let scopes = [
        "user-read-currently-playing",
        "user-read-recently-played",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-private",
        "user-read-email",
        "user-follow-read",
        "user-library-read",
        "user-read-playback-position",
        "user-top-read",
        "user-follow-read",
        "playlist-read-private",
        "playlist-read-collaborative"
    ]
    
    override init() {
        super.init()
        // Load tokens from keychain if available
        if let accessToken = KeychainManager.shared.getAccessToken(),
           let refreshToken = KeychainManager.shared.getRefreshToken(),
           let expirationDate = KeychainManager.shared.getTokenExpirationDate() {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.tokenExpirationDate = expirationDate
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Authentication URL
    private var authURL: URL? {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        return components?.url
    }
    
    // MARK: - Authentication Methods
    func authenticate() {
        guard let authURL = authURL else { return }
        
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "fete"
        ) { [weak self] callbackURL, error in
            guard let self = self,
                  error == nil,
                  let callbackURL = callbackURL,
                  let code = self.extractCode(from: callbackURL) else {
                return
            }
            
            Task {
                await self.exchangeCodeForToken(code: code)
            }
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }
    
    private func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
    
    private func exchangeCodeForToken(code: String) async {
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        // Create the authorization header
        let authString = "\(clientID):\(clientSecret)".data(using: String.Encoding.utf8)?.base64EncodedString() ?? ""
        request.addValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        
        // Create the request body
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI
        ]
        
        // Properly encode the parameters
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Failed to exchange code for token")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            // Store tokens
            self.accessToken = tokenResponse.access_token
            if let refreshToken = tokenResponse.refresh_token {
                self.refreshToken = refreshToken
                KeychainManager.shared.saveRefreshToken(refreshToken)
            }
            self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            self.isAuthenticated = true
            
            // Save to keychain
            KeychainManager.shared.saveAccessToken(tokenResponse.access_token)
            KeychainManager.shared.saveTokenExpirationDate(self.tokenExpirationDate!)
            
        } catch {
            print("Error exchanging code for token: \(error)")
            if let decodingError = error as? DecodingError {
                print("Decoding error details: \(decodingError)")
            }
        }
    }
    
    func refreshAccessToken() async {
        guard let refreshToken = self.refreshToken ?? KeychainManager.shared.getRefreshToken() else {
            print("No refresh token available")
            signOut()
            return
        }
        
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        // Create the authorization header
        let authString = "\(clientID):\(clientSecret)".data(using: String.Encoding.utf8)?.base64EncodedString() ?? ""
        request.addValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        
        // Create the request body
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        // Properly encode the parameters
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response during token refresh")
                return
            }
            
            if httpResponse.statusCode != 200 {
                print("Failed to refresh token with status code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                if httpResponse.statusCode == 401 {
                    // Token refresh failed, sign out user
                    signOut()
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            // Update tokens
            self.accessToken = tokenResponse.access_token
            if let newRefreshToken = tokenResponse.refresh_token {
                self.refreshToken = newRefreshToken
                KeychainManager.shared.saveRefreshToken(newRefreshToken)
            }
            self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            
            // Save to keychain
            KeychainManager.shared.saveAccessToken(tokenResponse.access_token)
            KeychainManager.shared.saveTokenExpirationDate(self.tokenExpirationDate!)
            
        } catch {
            print("Error refreshing token: \(error)")
            if let decodingError = error as? DecodingError {
                print("Decoding error details: \(decodingError)")
            }
            signOut()
        }
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        isAuthenticated = false
        
        // Remove from keychain
        KeychainManager.shared.removeAccessToken()
        KeychainManager.shared.removeRefreshToken()
        KeychainManager.shared.removeTokenExpirationDate()
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    // MARK: - Token Management
    func getValidAccessToken() async -> String? {
        // Check if we have a token and expiration date
        guard let accessToken = self.accessToken,
              let expirationDate = tokenExpirationDate else {
            return nil
        }
        
        // If token is expired or about to expire in the next 5 minutes, refresh it
        if Date().addingTimeInterval(300) >= expirationDate {
            await refreshAccessToken()
        }
        
        return self.accessToken
    }
}

// MARK: - Token Response
private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String
} 
