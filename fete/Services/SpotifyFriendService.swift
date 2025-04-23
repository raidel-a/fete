import Foundation
import SwiftUI


class SpotifyFriendService {
    static let shared = SpotifyFriendService()
    private var webPlayerToken: String?
    private var webPlayerTokenExpiration: Date?
    
    private func getWebPlayerToken() async throws -> String {
        // If we have a valid cached token, return it
        if let token = webPlayerToken,
           let expiration = webPlayerTokenExpiration,
           expiration > Date() {
            return token
        }
        
        // Get the sp_dc cookie from keychain
        guard let spDcCookie = KeychainManager.shared.getWebPlayerCookie() else {
            throw SpotifyServiceError.unauthorized
        }

        // Get current timestamp in milliseconds
        let currentTimeMs = Int(Date().timeIntervalSince1970 * 1000)
        let sTime = Int(currentTimeMs / 1000)
        let buildDate = "2025-04-07"
        let buildVer = "web-player_2025-04-07_1743986580456_e423c90"
        let clientId = "d8a5ed958d274c2e8ee717e6a4b0971d"
        
        // Construct URL with all required parameters
        let urlString = "https://open.spotify.com/get_access_token" +
            "?reason=init" +
            "&productType=web-player" +
            "&totp=808342" +
            "&totpServer=808342" +
            "&totpVer=5" +
            "&sTime=\(sTime)" +
            "&cTime=\(currentTimeMs)" +
            "&buildVer=\(buildVer)" +
            "&buildDate=\(buildDate)" +
            "&clientId=\(clientId)"
        
        guard let url = URL(string: urlString) else {
            throw SpotifyServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set all headers exactly as web player
        request.setValue("open.spotify.com", forHTTPHeaderField: "authority")
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("gzip, deflate, br, zstd", forHTTPHeaderField: "accept-encoding")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "accept-language")
        request.setValue("sentry-environment=production,sentry-release=\(buildVer),sentry-public_key=de32132fc06e4b28965ecf25332c3a25,sentry-trace_id=fed344c062db425c9137dcf8e04e3cb4,sentry-sample_rate=0.008,sentry-sampled=false", forHTTPHeaderField: "baggage")
        
        // Set all required cookies
        let cookies = [
            "sp_dc=\(spDcCookie)",
            "sp_gaid=0",
            "sp_t=2",
            "sp_landing=https%3A%2F%2Fopen.spotify.com%2F",
            "sp_m=us"
        ].joined(separator: "; ")
        request.setValue(cookies, forHTTPHeaderField: "cookie")
        
        request.setValue("1", forHTTPHeaderField: "dnt")
        request.setValue("u=1, i", forHTTPHeaderField: "priority")
        request.setValue("https://open.spotify.com/", forHTTPHeaderField: "referer")
        request.setValue("\"Chromium\";v=\"135\", \"Not-A.Brand\";v=\"8\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("fed344c062db425c9137dcf8e04e3cb4-962de737bfcf3b9c-0", forHTTPHeaderField: "sentry-trace")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36", forHTTPHeaderField: "user-agent")
        
        // Print full request for debugging
        print("\nRequest Debug:")
        print("URL: \(url)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("\nResponse Debug:")
            print("Status Code: \(httpResponse.statusCode)")
            print("Response Headers: \(httpResponse.allHeaderFields)")
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Body: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                throw SpotifyServiceError.unauthorized
            }
        }
        
        struct TokenResponse: Codable {
            let clientId: String
            let accessToken: String
            let accessTokenExpirationTimestampMs: Int64
            let isAnonymous: Bool
            let totpValidity: Bool
            let notes: String?
            
            enum CodingKeys: String, CodingKey {
                case clientId
                case accessToken
                case accessTokenExpirationTimestampMs
                case isAnonymous
                case totpValidity
                case notes = "_notes"
            }
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        
        // Validate token
        print("\nToken Debug:")
        print("Client ID: \(tokenResponse.clientId)")
        print("Access Token Length: \(tokenResponse.accessToken.count)")
        print("Token Expiration: \(tokenResponse.accessTokenExpirationTimestampMs)")
        print("Is Anonymous: \(tokenResponse.isAnonymous)")
        print("TOTP Validity: \(tokenResponse.totpValidity)")
        if let notes = tokenResponse.notes {
            print("Notes: \(notes)")
        }
        
        // Cache the token and its expiration date
        webPlayerToken = tokenResponse.accessToken
        webPlayerTokenExpiration = Date(timeIntervalSince1970: Double(tokenResponse.accessTokenExpirationTimestampMs) / 1000.0)
        
        return tokenResponse.accessToken
    }
    
    func fetchFriendActivity() async throws -> [FriendActivity] {
        // First get a web player token which will internally get the cookie from keychain
        let token = try await getWebPlayerToken()
        
        // Then get the buddy list using the token
        let url = URL(string: "https://guc-spclient.spotify.com/presence-view/v1/buddylist")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set authorization header
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add headers in exact order as web player
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
        request.setValue("https://open.spotify.com/", forHTTPHeaderField: "Referer")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

        // Print request debug info
        print("\nBuddy List Request Debug:")
        print("URL: \(url)")
        print("Authorization Header: '\(token)'")
        print("All Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("\nBuddy List Response Debug:")
            print("Status Code: \(httpResponse.statusCode)")
            print("Response Headers: \(httpResponse.allHeaderFields)")
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Body: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                throw SpotifyServiceError.unauthorized
            }
        }
        
        // Parse buddy list response
        struct BuddyListResponse: Codable {
            let friends: [Friend]
            
            struct Friend: Codable {
                let user: User
                let timestamp: String
                let track: TrackInfo
                
                struct User: Codable {
                    let uri: String
                    let name: String
                    let imageUrl: String?
                }
                
                struct TrackInfo: Codable {
                    let uri: String
                    let name: String
                    let imageUrl: String?
                    let artist: Artist
                    let album: Album
                    let context: Context?
                }
                
                struct Artist: Codable {
                    let id: String
                    let uri: String
                    let name: String
                    let images: [Image]?
                    
                    struct Image: Codable {
                        let url: String
                        let height: Int?
                        let width: Int?
                    }
                }
                
                struct Album: Codable {
                    let id: String
                    let uri: String
                    let name: String
                    let images: [Image]
                    let releaseDate: String?
                    let totalTracks: Int?
                    let albumType: String?
                    
                    struct Image: Codable {
                        let url: String
                        let height: Int?
                        let width: Int?
                    }
                }
                
                struct Context: Codable {
                    let id: String
                    let uri: String
                    let name: String
                    let index: Int?
                }
            }
        }
        
        let decoder = JSONDecoder()
        let buddyList = try decoder.decode(BuddyListResponse.self, from: data)
        
        // Convert buddy list to FriendActivity array
        return buddyList.friends.map { friend in
            let user = SpotifyUser(
                name: friend.user.name,
                uri: friend.user.uri,
                imageUrl: friend.user.imageUrl
            )
            
            let artist = Artist(
                id: friend.track.artist.uri,
                uri: friend.track.artist.uri,
                name: friend.track.artist.name,
                images: friend.track.artist.images?.map { image in
                    Artist.Image(url: image.url, height: image.height, width: image.width)
                }
            )
            
            let album = Album(
                id: friend.track.album.uri,
                uri: friend.track.album.uri,
                name: friend.track.album.name,
                images: friend.track.album.images.map { image in
                    Album.Image(url: image.url, height: image.height, width: image.width)
                },
                releaseDate: nil,
                totalTracks: nil,
                albumType: nil
            )
            
            let context = friend.track.context.map { ctx in
                Context(
                    id: ctx.uri,
                    uri: ctx.uri,
                    name: ctx.name,
                    index: ctx.index
                )
            }
            
            let track = Track(
                id: friend.track.uri,
                uri: friend.track.uri,
                name: friend.track.name,
                artists: [artist],
                album: album,
                context: context,
                position: nil,
                durationMs: nil,
                popularity: nil,
                explicit: nil,
                playedAt: nil,
                previewUrl: nil
            )
            
            return FriendActivity(
                timestamp: friend.timestamp,
                user: user,
                track: track
            )
        }
    }
}

enum SpotifyServiceError: Error {
    case unauthorized
    case invalidResponse
    case networkError(Error)
}
