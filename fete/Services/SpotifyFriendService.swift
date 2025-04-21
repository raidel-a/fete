import Foundation
import SwiftUI
import CommonCrypto


class SpotifyFriendService {
    static let shared = SpotifyFriendService()
    private var webPlayerToken: String?
    private var webPlayerTokenExpiration: Date?
    
    private func getExternalTOTP() async throws -> TOTPResponse {
        guard let url = URL(string: "https://totp-gateway.glitch.me/create") else {
            throw SpotifyServiceError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyServiceError.invalidResponse
        }
        
        return try JSONDecoder().decode(TOTPResponse.self, from: data)
    }
    
    private func getWebPlayerToken() async throws -> String {
        let totpResponse = try await getExternalTOTP()
        
        var components = URLComponents(string: "https://open.spotify.com/get_access_token")!
        components.queryItems = [
            URLQueryItem(name: "reason", value: "init"),
            URLQueryItem(name: "productType", value: "web-player"),
            URLQueryItem(name: "totp", value: totpResponse.totp),
            URLQueryItem(name: "totpVer", value: "5"),
            URLQueryItem(name: "cTime", value: String(totpResponse.timestamp))
        ]
        
        guard let url = components.url else {
            throw SpotifyServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("en", forHTTPHeaderField: "accept-language")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "user-agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyServiceError.unauthorized
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let accessToken = json?["accessToken"] as? String else {
            throw SpotifyServiceError.invalidResponse
        }
        
        return accessToken
    }
    
    func fetchFriendActivity() async throws -> [FriendActivity] {
        let accessToken = try await getWebPlayerToken()
        
        guard let url = URL(string: "https://spclient.wg.spotify.com/presence-view/v1/buddylist") else {
            throw SpotifyServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("en", forHTTPHeaderField: "accept-language")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "user-agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyServiceError.unauthorized
        }
        
        // Print response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📝 Buddylist Response: \(responseString)")
        }
        
        let buddyList = try JSONDecoder().decode(BuddyListResponse.self, from: data)
        return buddyList.friends
    }
}

enum SpotifyServiceError: Error {
    case unauthorized
    case invalidResponse
    case networkError(Error)
}

private struct WebPlayerTokenResponse: Codable {
    let clientId: String
    let accessToken: String
    let accessTokenExpirationTimestampMs: Int64
    let isAnonymous: Bool
    let totpValidity: Int
}

private func generateTOTP(timestamp: Int64) -> String {
    let interval: Int64 = 30
    let timeBlock = timestamp / (interval * 1000)
    
    var timeBytes = withUnsafeBytes(of: timeBlock.bigEndian) { Array($0) }
    
    // Create a key for HMAC (using a fixed key for demonstration)
    let key = "spotify_totp_key".data(using: .utf8)!.map { UInt8($0) }
    
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1),
           key, // Key
           key.count, // Key length
           timeBytes, // Data
           timeBytes.count, // Data length
           &hash) // Output buffer
    
    // Get offset
    let offset = hash[hash.count - 1] & 0x0f
    
    // Generate 6-digit TOTP
    let binary = ((Int(hash[Int(offset)]) & 0x7f) << 24) |
                ((Int(hash[Int(offset + 1)]) & 0xff) << 16) |
                ((Int(hash[Int(offset + 2)]) & 0xff) << 8) |
                (Int(hash[Int(offset + 3)]) & 0xff)
    
    let otp = binary % 1000000
    return String(format: "%06d", otp)
}

private struct TOTPResponse: Codable {
    let totp: String
    let timestamp: Int64
}
