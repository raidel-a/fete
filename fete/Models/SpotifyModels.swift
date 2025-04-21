import Foundation

    // MARK: - Spotify Token Response
struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let spDc: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case spDc = "sp_dc"
    }
}

    // MARK: - Activity Models
struct PlayHistoryResponse: Codable {
    let items: [PlayHistoryItem]
}

struct PlayHistoryItem: Codable, Identifiable {
    var track: Track
    let playedAt: String
    let context: Context?
    
    var id: String {
        "\(track.id)_\(playedAt)"
    }
}

struct TracksResponse: Codable {
    let items: [Track]
    let total: Int
    let limit: Int
    let offset: Int
    let previous: String?
    let next: String?
}

struct ArtistsResponse: Codable {
    let items: [Artist]
    let total: Int
    let limit: Int
    let offset: Int
    let previous: String?
    let next: String?
}

    // MARK: - Core Models
struct Track: Codable, Identifiable, Equatable {
    let id: String
    let uri: String
    let name: String
    let artists: [Artist]
    let album: Album
    let context: Context?
    var position: Int?
    let durationMs: Int?
    let popularity: Int?
    let explicit: Bool?
    let playedAt: Date?
    let previewUrl: String?
    
    var imageUrl: String? {
        album.imageUrl
    }
    
    var uniqueId: String {
        if let position = position {
            return "\(id)_\(position)"
        }
        return id
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.uniqueId == rhs.uniqueId
    }
}

struct Artist: Codable, Identifiable, Equatable {
    let id: String
    let uri: String
    let name: String
    let images: [Image]?
    
    var imageUrl: String? {
        // Get the first image URL from the array
        images?.first?.url
    }
    
    struct Image: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id
    }
}

struct Album: Codable, Identifiable, Equatable {
    let id: String
    let uri: String
    let name: String
    let images: [Image]
    let releaseDate: Date?
    let totalTracks: Int?
    let albumType: String?
    
    var imageUrl: String? {
        // Get the first image URL from the array
        images.first?.url
    }
    
    struct Image: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case uri
        case name
        case images
        case releaseDate = "release_date"
        case totalTracks = "total_tracks"
        case albumType = "album_type"
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}

struct Context: Codable, Identifiable, Equatable {
    let id: String?
    let uri: String
    let name: String?
    let index: Int?
    
    static func == (lhs: Context, rhs: Context) -> Bool {
        lhs.uri == rhs.uri
    }
}

    // MARK: - Friend Activity
struct FriendActivityResponse: Codable {
    let friends: [FriendActivity]
}

struct FriendActivity: Codable, Equatable {
    let timestamp: Int64
    let user: User
    let track: FriendTrack
}

struct User: Codable, Equatable {
    let uri: String
    let name: String
    let imageUrl: String?
}

    // MARK: - User Profile
struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String?
    let images: [ProfileImage]?
    let email: String?
    let product: String?
    
    struct ProfileImage: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }
}

    // MARK: - Enums
enum TimeRange: String {
    case shortTerm = "short_term"    // Last 4 weeks
    case mediumTerm = "medium_term"  // Last 6 months
    case longTerm = "long_term"      // All time
}

struct BuddyListResponse: Codable {
    let friends: [FriendActivity]
}

// New model specifically for friend activity track data
struct FriendTrack: Codable, Equatable {
    let uri: String
    let name: String
    let imageUrl: String
    let album: FriendAlbum
    let artist: FriendArtist
    let context: FriendContext?
}

struct FriendAlbum: Codable, Equatable {
    let uri: String
    let name: String
}

struct FriendArtist: Codable, Equatable {
    let uri: String
    let name: String
}

struct FriendContext: Codable, Equatable {
    let uri: String
    let name: String
    let index: Int
}
