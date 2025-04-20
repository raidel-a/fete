import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
// Header section (non-scrollable)
                HeaderView(
                    artists: viewModel.topArtists,
                    selectedTab: $selectedTab,
                    onLoadMore: { await viewModel.loadMoreTopArtists() },
                    scrollProxy: proxy
                )
                
// Tracks section (scrollable)
                TracksContentView(
                    selectedTab: selectedTab,
                    recentlyPlayed: viewModel.recentlyPlayed,
                    topTracks: viewModel.topTracks,
                    onLoadMoreRecent: { await viewModel.loadMoreRecentlyPlayed() },
                    onLoadMoreTop: { await viewModel.loadMoreTopTracks() },
                    onRefreshRecent: { await viewModel.refreshRecentlyPlayed() },
                    onRefreshTop: { await viewModel.refreshTopTracks() }
                )
            }
        }
    }
}

#Preview {
    MainContentView(
        viewModel: ContentViewModel(),
        selectedTab: .constant(0)
    )
}