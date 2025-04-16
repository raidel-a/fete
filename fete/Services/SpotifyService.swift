import Foundation

class SpotifyService {
    static let shared = SpotifyService()
    private let baseURL = "https://api.spotify.com/v1"
    
    private init() {}
    
    // MARK: - User Profile
    
    func fetchUserProfile(accessToken: String) async throws -> UserProfile {
        let url = URL(string: "\(baseURL)/me")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "SpotifyService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user profile"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UserProfile.self, from: data)
    }
    
    // MARK: - Currently Playing
    
    func fetchCurrentlyPlaying(accessToken: String) async throws -> CurrentlyPlaying? {
        let url = URL(string: "\(baseURL)/me/player/currently-playing")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "SpotifyService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }
        
        // If nothing is playing, Spotify returns 204
        if httpResponse.statusCode == 204 {
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "SpotifyService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch currently playing"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CurrentlyPlaying.self, from: data)
    }
    
    // MARK: - Playlists
    
    func fetchUserPlaylists(accessToken: String) async throws -> [Playlist] {
        let url = URL(string: "\(baseURL)/me/playlists")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "SpotifyService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch playlists"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let playlistResponse = try decoder.decode(PlaylistResponse.self, from: data)
        return playlistResponse.items
    }
}

// MARK: - Response Models

struct CurrentlyPlaying: Codable {
    let isPlaying: Bool
    let item: Track?
    let progressMs: Int?
    
    struct Track: Codable {
        let id: String
        let name: String
        let uri: String
        let album: Album
        let artists: [Artist]
        
        struct Album: Codable {
            let name: String
            let images: [Image]
            
            struct Image: Codable {
                let url: String
                let height: Int
                let width: Int
            }
        }
        
        struct Artist: Codable {
            let id: String
            let name: String
        }
    }
}

struct PlaylistResponse: Codable {
    let items: [Playlist]
}

struct Playlist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let images: [Image]
    let owner: Owner
    
    struct Image: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    struct Owner: Codable {
        let id: String
        let displayName: String?
    }
} 