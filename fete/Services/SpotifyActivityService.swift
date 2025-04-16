import Foundation

class SpotifyActivityService {
    static let shared = SpotifyActivityService()
    private let baseURL = "https://api.spotify.com/v1"
    
    private init() {}
    
    // MARK: - User Profile
    
    func fetchUserProfile(accessToken: String) async throws -> UserProfile {
        let url = URL(string: "\(baseURL)/me")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "SpotifyActivityService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Error response: \(responseString)")
            }
            throw NSError(
                domain: "SpotifyActivityService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user profile"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UserProfile.self, from: data)
    }
    
    // MARK: - Recently Played Tracks
    
    func fetchRecentlyPlayed(accessToken: String, limit: Int = 15, before: String? = nil) async throws -> [PlayHistoryItem] {
        var urlComponents = URLComponents(string: "\(baseURL)/me/player/recently-played")!
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let before {
            queryItems.append(URLQueryItem(name: "before", value: before))
        }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "SpotifyActivityService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(
                    domain: "SpotifyActivityService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to fetch recently played tracks"]
                )
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            var historyResponse = try decoder.decode(PlayHistoryResponse.self, from: data)
            
            // Add position to each track
            var items: [PlayHistoryItem] = []
            for (index, var item) in historyResponse.items.enumerated() {
                item.track.position = index
                items.append(item)
            }
            
            return items
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == -999 {
            // Request was cancelled, return empty array
            return []
        } catch {
            throw error
        }
    }
    
    // MARK: - Top Tracks
    
    func fetchTopTracks(accessToken: String, timeRange: TimeRange = .mediumTerm, limit: Int = 50, offset: Int = 0) async throws -> [Track] {
        let url = URL(string: "\(baseURL)/me/top/tracks?time_range=\(timeRange.rawValue)&limit=\(limit)&offset=\(offset)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("Fetching top tracks with limit: \(limit), offset: \(offset)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "SpotifyActivityService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }
        
        print("Top tracks response status: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Error response: \(responseString)")
            }
            throw NSError(
                domain: "SpotifyActivityService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch top tracks"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tracksResponse = try decoder.decode(TracksResponse.self, from: data)
        print("Received \(tracksResponse.items.count) tracks, total: \(tracksResponse.total), next: \(tracksResponse.next ?? "none")")
        return tracksResponse.items
    }
    
    // MARK: - Top Artists
    
    func fetchTopArtists(accessToken: String, timeRange: TimeRange = .mediumTerm, limit: Int = 50, offset: Int = 0) async throws -> [Artist] {
        let url = URL(string: "\(baseURL)/me/top/artists?time_range=\(timeRange.rawValue)&limit=\(limit)&offset=\(offset)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("Fetching top artists with limit: \(limit), offset: \(offset)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "SpotifyActivityService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }
        
        print("Top artists response status: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Error response: \(responseString)")
            }
            throw NSError(
                domain: "SpotifyActivityService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch top artists"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let artistsResponse = try decoder.decode(ArtistsResponse.self, from: data)
        print("Received \(artistsResponse.items.count) artists, total: \(artistsResponse.total), next: \(artistsResponse.next ?? "none")")
        return artistsResponse.items
    }
} 