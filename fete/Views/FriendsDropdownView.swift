import SwiftUI

// Main container view that handles the dropdown state
struct FriendsDropdownButton: View {
    @StateObject private var friendsViewModel = SpotifyFriendsViewModel()
    @State private var showingFriendSheet = false
    
    var body: some View {
        Button(action: {
            showingFriendSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 14))
                Text("Friends")
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(16)
        }
        .sheet(isPresented: $showingFriendSheet) {
            NavigationView {
                FriendsDetailView(friends: friendsViewModel.friendActivities)
                    .navigationTitle("Friend Activity")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingFriendSheet = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            Task {
                await friendsViewModel.loadFriends()
            }
        }
    }
}

// New view for detailed friend list in sheet
struct FriendsDetailView: View {
    let friends: [FriendActivity]
    
    var body: some View {
        List(friends, id: \.user.uri) { friend in
            FriendActivityRow(friend: friend)
        }
    }
}

// Updated FriendActivityRow to be more compact
private struct FriendActivityRow: View {
    let friend: FriendActivity
    
    private var timeAgo: String {
        let timestamp = TimeInterval(friend.timestamp / 1000)
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: {
            if let spotifyURL = URL(string: friend.track.uri) {
                UIApplication.shared.open(spotifyURL)
            }
        }) {
            HStack(spacing: 12) {
                // User Profile
                AsyncImage(url: URL(string: friend.user.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // User and time
                    HStack {
                        Text(friend.user.name)
                            .font(.system(size: 14, weight: .medium))
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(timeAgo)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Track info
                    HStack(spacing: 8) {
                        // Album art
                        AsyncImage(url: URL(string: friend.track.imageUrl)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(friend.track.name)
                                .font(.system(size: 13))
                            Text(friend.track.artist.name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Context (if available)
                    if let context = friend.track.context {
                        Text("From: \(context.name)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ViewModel for handling friends data
class SpotifyFriendsViewModel: ObservableObject {
    @Published var friendActivities: [FriendActivity] = []
    @Published var isLoading = false
    @Published var debugStatus = "Starting"
    @Published var error: String?
    private let friendService = SpotifyFriendService.shared
    
    func loadFriends() async {
        print("🔄 LoadFriends started")
        await MainActor.run { 
            debugStatus = "Setting loading state"
            isLoading = true 
            error = nil
        }
        
        do {
            debugStatus = "Fetching friends from new endpoint"
            print("🔄 Fetching friend activity...")
            let friends = try await friendService.fetchFriendActivity()
            print("✅ Friend activity fetched, count: \(friends.count)")
            debugStatus = "Got \(friends.count) friends"
            
            await MainActor.run {
                self.friendActivities = friends
                self.isLoading = false
                print("✅ Updated friendActivities, new count: \(self.friendActivities.count)")
            }
        } catch {
            print("❌ Error loading friends: \(error)")
            await MainActor.run { 
                self.error = "Error: \(error.localizedDescription)"
                self.isLoading = false 
            }
        }
    }
}

#Preview {
    FriendsDropdownButton()
} 