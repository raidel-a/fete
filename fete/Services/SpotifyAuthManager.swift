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
    private let clientID: String? 
    private let clientSecret: String?
    private let redirectURI: String?
    
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
        // Initialize configuration values
        do {
            print("Attempting to load configuration...")
            let clientID = try Configuration.value(for: "SPOTIFY_CLIENT_ID") as String
            let clientSecret = try Configuration.value(for: "SPOTIFY_CLIENT_SECRET") as String
            let baseRedirectURI = try Configuration.value(for: "SPOTIFY_REDIRECT_URI") as String
            
            // Ensure the redirect URI is properly formatted
            let redirectURI = baseRedirectURI.hasSuffix("://callback") 
                ? baseRedirectURI 
                : "\(baseRedirectURI)//callback"
            
            print("Configuration loaded successfully:")
            print("Client ID: \(clientID.prefix(5))...")
            print("Redirect URI: \(redirectURI)")
            
            self.clientID = clientID
            self.clientSecret = clientSecret
            self.redirectURI = redirectURI
        } catch {
            print("Configuration error: \(error)")
            fatalError("Missing required configuration. Ensure all keys are set in Config.xcconfig")
        }

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
    var authURL: URL? {
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
    // We'll handle the web flow ourselves with SpotifyWebView
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    // MARK: - Token Management
    func getValidAccessToken() async -> String? {
        if let expirationDate = tokenExpirationDate,
           let accessToken = accessToken,
           expirationDate > Date() {
            return accessToken
        }
        
        do {
            await refreshAccessToken()
            return accessToken
        } catch {
            print("Error refreshing token: \(error)")
            return nil
        }
    }
    
    func refreshAccessToken() async {
        guard let refreshToken = self.refreshToken ?? KeychainManager.shared.getRefreshToken() else {
            print("No refresh token available")
            return
        }
        
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        guard let clientID = clientID, let clientSecret = clientSecret else {
            print("Missing client credentials")
            return
        }
        
        let authString = "\(clientID):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        request.addValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Failed to refresh token")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                return
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            self.accessToken = tokenResponse.access_token
            self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            
            KeychainManager.shared.saveAccessToken(tokenResponse.access_token)
            KeychainManager.shared.saveTokenExpirationDate(self.tokenExpirationDate!)
            
            if let newRefreshToken = tokenResponse.refresh_token {
                self.refreshToken = newRefreshToken
                KeychainManager.shared.saveRefreshToken(newRefreshToken)
            }
            
        } catch {
            print("Error refreshing token: \(error)")
        }
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        isAuthenticated = false
        
        KeychainManager.shared.removeAccessToken()
        KeychainManager.shared.removeRefreshToken()
        KeychainManager.shared.removeTokenExpirationDate()
        KeychainManager.shared.removeSpotifyDCCookie()
    }
    
    func exchangeCodeForToken(_ code: String) async throws {
        guard let clientID = clientID,
              let clientSecret = clientSecret,
              let redirectURI = redirectURI else {
            throw NSError(domain: "SpotifyAuthManager", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Missing configuration"])
        }
        
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        // Create the authorization header
        let authString = "\(clientID):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        
        // Create the request body
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI
        ]
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyParams
            .map { "\($0)=\($1)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "SpotifyAuthManager", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Token exchange failed"])
        }
        
        struct TokenResponse: Codable {
            let accessToken: String
            let tokenType: String
            let expiresIn: Int
            let refreshToken: String
            let scope: String
            
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case tokenType = "token_type"
                case expiresIn = "expires_in"
                case refreshToken = "refresh_token"
                case scope
            }
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        
        // Save tokens
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        // Save to keychain
        KeychainManager.shared.saveAccessToken(tokenResponse.accessToken)
        KeychainManager.shared.saveRefreshToken(tokenResponse.refreshToken)
        KeychainManager.shared.saveTokenExpirationDate(self.tokenExpirationDate!)
        
        print("✅ Successfully exchanged code for tokens")
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
