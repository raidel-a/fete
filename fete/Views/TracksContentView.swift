import SwiftUI

struct TracksContentView: View {
    let selectedTab: Int
    let recentlyPlayed: [PlayHistoryItem]
    let topTracks: [Track]
    let onLoadMoreRecent: () async -> Void
    let onLoadMoreTop: () async -> Void
    let onRefreshRecent: () async -> Void
    let onRefreshTop: () async -> Void
    @State private var isRefreshing = false
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            Color.clear
                .frame(height: 0)
                .id(ScrollToTop.tracks)

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        if selectedTab == 0 {
                            ActivitySection(
                                title: nil,
                                items: convertToTracks(from: recentlyPlayed),
                                onLoadMore: onLoadMoreRecent
                            )
                        } else {
                            ActivitySection(
                                title: nil,
                                items: topTracks,
                                onLoadMore: onLoadMoreTop
                            )
                        }
                        
                        Color.black
                            .frame(height: 0)
                    }
                }
                .refreshable {
                    guard !isRefreshing else { return }
                    
                    // Cancel any existing refresh task
                    refreshTask?.cancel()
                    
                    // Create new refresh task
                    refreshTask = Task {
                        isRefreshing = true
                        do {
                            if selectedTab == 0 {
                                await onRefreshRecent()
                            } else {
                                await onRefreshTop()
                            }
                        } catch {
                            print("Refresh error: \(error.localizedDescription)")
                        }
                        isRefreshing = false
                    }
                    
                    // Wait for the refresh task to complete
                    await refreshTask?.value
                }
                .scrollIndicators(.hidden)
                
                // Gradient overlay at the bottom
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor.systemBackground).opacity(0),
                            Color(UIColor.systemBackground)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
        .onChange(of: selectedTab) { _ in
            // Cancel any ongoing refresh when switching tabs
            refreshTask?.cancel()
            isRefreshing = false
        }
        .padding(.horizontal)
    }
    
    private func convertToTracks(from playHistory: [PlayHistoryItem]) -> [Track] {
        playHistory.map { item in
            // Convert the playedAt string to a Date
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let playedAtDate = dateFormatter.date(from: item.playedAt)

            return Track(
                id: item.track.id,
                uri: item.track.uri,
                name: item.track.name,
                artists: item.track.artists,
                album: item.track.album,
                context: item.track.context,
                position: item.track.position,
                durationMs: item.track.durationMs,
                popularity: item.track.popularity,
                explicit: item.track.explicit,
                playedAt: playedAtDate,
                previewUrl: item.track.previewUrl
            )
        }
    }
}

#Preview {
    TracksContentView(
        selectedTab: 0,
        recentlyPlayed: [],
        topTracks: [
            Track(
                id: "1",
                uri: "spotify:track:1",
                name: "Track 1",
                artists: [Artist(id: "1", uri: "spotify:artist:1", name: "Artist 1", images: nil)],
                album: Album(
                    id: "1",
                    uri: "spotify:album:1",
                    name: "Album 1",
                    images: [],
                    releaseDate: nil,
                    totalTracks: nil,
                    albumType: nil
                ),
                context: nil,
                position: 0,
                durationMs: 180000,
                popularity: 80,
                explicit: false,
                playedAt: nil,
                previewUrl: nil
            )
        ],
        onLoadMoreRecent: { },
        onLoadMoreTop: { },
        onRefreshRecent: { },
        onRefreshTop: { }
    )
}


struct ActivitySection: View {
  let title: String?
  let items: [Track]
  var onLoadMore: (() async -> Void)?
  @State private var isLoadingMore = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let title = title {
        Text(title)
          .font(.title2)
          .fontWeight(.bold)
      }

      LazyVStack(spacing: 8) {
        ForEach(items, id: \.uniqueId) { track in
          TrackRow(track: track)
            .task {
              if track == items.last, !isLoadingMore {
                isLoadingMore = true
                await onLoadMore?()
                isLoadingMore = false
              }
            }
        }
      }
    }
  }
}