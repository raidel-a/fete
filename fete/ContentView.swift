//
//  ContentView.swift
//  fete
//
//  Created by Raidel Almeida on 4/3/25.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var recentlyPlayed: [PlayHistoryItem] = []
    @Published var topTracks: [Track] = []
    @Published var topArtists: [Artist] = []
    @Published var isLoading = false
    @Published var isLoadingMoreTracks = false
    @Published var isLoadingMoreArtists = false
    @Published var isLoadingMoreRecent = false
    @Published var error: Error?
    @Published var userProfile: UserProfile?
    
    // Pagination state
    private var canLoadMoreRecentlyPlayed = true
    private var canLoadMoreTopTracks = true
    private var canLoadMoreTopArtists = true
    private var lastRecentlyPlayedTimestamp: String?
    private var topTracksOffset = 0
    private var topArtistsOffset = 0
    private let pageSize = 10
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSpotifyAuthObservers()
    }
    
    private func setupSpotifyAuthObservers() {
        SpotifyAuthManager.shared.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                if isAuthenticated {
                    Task {
                        await self?.fetchInitialData()
                        await self?.fetchUserProfile()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchUserProfile() async {
        do {
            guard let accessToken = await SpotifyAuthManager.shared.getValidAccessToken() else {
                throw NSError(domain: "ContentViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token available"])
            }
            
            self.userProfile = try await SpotifyActivityService.shared.fetchUserProfile(accessToken: accessToken)
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
    
    func fetchInitialData() async {
        isLoading = true
        error = nil
        
        // Reset pagination state
        canLoadMoreRecentlyPlayed = true
        canLoadMoreTopTracks = true
        canLoadMoreTopArtists = true
        lastRecentlyPlayedTimestamp = nil
        topTracksOffset = 0
        topArtistsOffset = 0
        
        // Clear existing data
        recentlyPlayed = []
        topTracks = []
        topArtists = []
        
        do {
            // Load first page of each section
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadMoreRecentlyPlayed() }
                group.addTask { await self.loadMoreTopTracks() }
                group.addTask { await self.loadMoreTopArtists() }
                try await group.waitForAll()
            }
        } catch {
            self.error = error
            print("Error fetching initial data: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMoreRecentlyPlayed() async {
        guard !isLoadingMoreRecent && canLoadMoreRecentlyPlayed else { return }
        
        isLoadingMoreRecent = true
        print("Loading more recently played tracks")
        
        do {
            guard let accessToken = await SpotifyAuthManager.shared.getValidAccessToken() else {
                throw NSError(
                    domain: "ContentViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No access token available"]
                )
            }
            
            let timestamp = lastRecentlyPlayedTimestamp ?? "\(Int(Date().timeIntervalSince1970 * 1000))"
            let newItems = try await SpotifyActivityService.shared.fetchRecentlyPlayed(
                accessToken: accessToken,
                limit: pageSize,
                before: timestamp
            )
            
            if newItems.isEmpty {
                print("No more recently played tracks available")
                canLoadMoreRecentlyPlayed = false
            } else {
                print("Loaded \(newItems.count) more recently played tracks")
                await MainActor.run {
                    self.recentlyPlayed.append(contentsOf: newItems)
                    if let lastItem = newItems.last {
                        self.lastRecentlyPlayedTimestamp = lastItem.playedAt
                    }
                }
            }
        } catch {
            self.error = error
            print("Error loading more recently played tracks: \(error)")
        }
        
        isLoadingMoreRecent = false
    }
    
    func loadMoreTopTracks() async {
        guard !isLoadingMoreTracks && canLoadMoreTopTracks else { return }
        
        isLoadingMoreTracks = true
        print("Loading more top tracks from offset \(topTracksOffset)")
        
        do {
            guard let accessToken = await SpotifyAuthManager.shared.getValidAccessToken() else {
                throw NSError(
                    domain: "ContentViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No access token available"]
                )
            }
            
            let newItems = try await SpotifyActivityService.shared.fetchTopTracks(
                accessToken: accessToken,
                limit: pageSize,
                offset: topTracksOffset
            )
            
            if newItems.isEmpty {
                print("No more top tracks available")
                canLoadMoreTopTracks = false
            } else {
                print("Loaded \(newItems.count) more top tracks")
                await MainActor.run {
                    self.topTracks.append(contentsOf: newItems)
                    self.topTracksOffset += newItems.count
                }
            }
        } catch {
            self.error = error
            print("Error loading more top tracks: \(error)")
        }
        
        isLoadingMoreTracks = false
    }
    
    func loadMoreTopArtists() async {
        guard !isLoadingMoreArtists && canLoadMoreTopArtists else { return }
        
        isLoadingMoreArtists = true
        print("Loading more top artists from offset \(topArtistsOffset)")
        
        do {
            guard let accessToken = await SpotifyAuthManager.shared.getValidAccessToken() else {
                throw NSError(
                    domain: "ContentViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No access token available"]
                )
            }
            
            let newItems = try await SpotifyActivityService.shared.fetchTopArtists(
                accessToken: accessToken,
                limit: pageSize,
                offset: topArtistsOffset
            )
            
            if newItems.isEmpty {
                print("No more top artists available")
                canLoadMoreTopArtists = false
            } else {
                print("Loaded \(newItems.count) more top artists")
                await MainActor.run {
                    self.topArtists.append(contentsOf: newItems)
                    self.topArtistsOffset += newItems.count
                }
            }
        } catch {
            self.error = error
            print("Error loading more top artists: \(error)")
        }
        
        isLoadingMoreArtists = false
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var authViewModel = AuthenticationViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if !viewModel.isAuthenticated {
                AuthenticationView(authViewModel: authViewModel)
            } else {
                NavigationStack {
                    Group {
                        if viewModel.isLoading && viewModel.recentlyPlayed.isEmpty {
                            LoadingView()
                        } else if let error = viewModel.error {
                            ErrorView(error: error, retryAction: {
                                Task {
                                    await viewModel.fetchInitialData()
                                }
                            })
                        } else {
                            MainContentView(viewModel: viewModel, selectedTab: $selectedTab)
                        }
                    }
                    .navigationTitle("Your Activity")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            UserProfileButton(
                                userProfile: viewModel.userProfile,
                                onSignOut: {
                                    SpotifyAuthManager.shared.signOut()
                                }
                            )
                        }
                    }
                    .toolbarBackground(.thinMaterial, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .refreshable {
                        await viewModel.fetchInitialData()
                    }
                }
                .task {
                    await viewModel.fetchInitialData()
                }
            }
        }
    }
}

// MARK: - Subviews

struct LoadingView: View {
    var body: some View {
        ProgressView("Loading activity...")
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack {
            Text("Error loading activity")
                .foregroundColor(.red)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.gray)
            
            Button("Retry", action: retryAction)
                .padding()
        }
    }
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

struct ArtistsSection: View {
    let title: String
    let artists: [Artist]
    var onLoadMore: (() async -> Void)?
    @State private var isLoadingMore = false
    @State private var currentPage = 0
    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var isLongPressing = false
    
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 100
    private let cardSpacing: CGFloat = 10
    private let cardsPerPage = 3
    private let borderRadius: CGFloat = 8
    
    private var numberOfPages: Int {
        (artists.count + cardsPerPage - 1) / cardsPerPage
    }
    
    private var horizontalPadding: CGFloat {
        let totalCardsWidth = cardWidth * CGFloat(cardsPerPage)
        let totalSpacingWidth = cardSpacing * CGFloat(cardsPerPage - 1)
        let screenWidth = UIScreen.main.bounds.width
        return (screenWidth - (totalCardsWidth + totalSpacingWidth)) / 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ZStack {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(0..<numberOfPages, id: \.self) { page in
                            HStack(spacing: cardSpacing) {
                                ForEach(0..<cardsPerPage, id: \.self) { index in
                                    let artistIndex = page * cardsPerPage + index
                                    if artistIndex < artists.count {
                                        ArtistCard(artist: artists[artistIndex])
                                            .frame(width: cardWidth, height: cardHeight)
                                            .scaleEffect(currentPage == page ? 1.0 : 0.8)
                                            .opacity(currentPage == page ? 1.0 : 0.5)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                                    }
                                }
                            }
                            .frame(width: geometry.size.width)
                        }
                    }
                    .offset(x: -CGFloat(currentPage) * geometry.size.width + dragOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let threshold = geometry.size.width * 0.2
                                var newPage = currentPage
                                
                                if value.predictedEndTranslation.width < -threshold && currentPage < numberOfPages - 1 {
                                    newPage += 1
                                } else if value.predictedEndTranslation.width > threshold && currentPage > 0 {
                                    newPage -= 1
                                }
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    currentPage = newPage
                                }
                                
                                // Load more content when reaching the last page
                                if newPage == numberOfPages - 1 && !isLoadingMore {
                                    Task {
                                        isLoadingMore = true
                                        await onLoadMore?()
                                        isLoadingMore = false
                                    }
                                }
                            }
                    )
                }
                .frame(height: cardHeight)

                // Navigation Bars
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentPage -= 1
                            }
                        }) {
                            Rectangle()
                                .fill(Color.black.opacity(0.0))
                                .frame(width: 23, height: 30)
                                .cornerRadius(borderRadius)
                                .overlay(
                                    Image(systemName: "chevron.compact.left")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.black.opacity(0.4))
                                        .shadow(radius: 20)
                                        .scaleEffect(isLongPressing ? 1.2 : 1.0)
                                )
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 1.0)
                                .updating($isLongPressing) { currentState, gestureState, _ in
                                    gestureState = currentState
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        currentPage = 0
                                    }
                                }
                        )
                        .transition(.opacity)
                    } else {
                        Rectangle()
                            .fill(Color.black.opacity(0.0))
                            .frame(width: 23, height: 30)
                            .cornerRadius(borderRadius)
                            .overlay(
                                Image(systemName: "line.diagonal")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black.opacity(0.4))
                                    .shadow(radius: 20)
                                    .rotationEffect(.degrees(-45))
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale),
                                removal: .opacity.combined(with: .scale)
                            ))
                    }
                    
                    Spacer()
                    
                    if currentPage < numberOfPages - 1 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentPage += 1
                            }
                            
                            // Load more content when reaching the last page
                            if currentPage + 1 == numberOfPages - 1 && !isLoadingMore {
                                Task {
                                    isLoadingMore = true
                                    await onLoadMore?()
                                    isLoadingMore = false
                                }
                            }
                        }) {
                            Rectangle()
                                .fill(Color.black.opacity(0.0))
                                .frame(width: 23, height: 30)
                                .cornerRadius(borderRadius)
                                .overlay(
                                    Image(systemName: "chevron.compact.right")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.black.opacity(0.4))
                                        .shadow(radius: 20)
                                )
                        }
                        .transition(.opacity)
                    } else {
                        Rectangle()
                            .fill(Color.black.opacity(0.0))
                            .frame(width: 23, height: 30)
                            .cornerRadius(borderRadius)
                            .overlay(
                                Image(systemName: "line.diagonal")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black.opacity(0.4))
                                    .shadow(radius: 20)
                                    .rotationEffect(.degrees(-45))
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale),
                                removal: .opacity.combined(with: .scale)
                            ))
                    }
                }
                .padding(.horizontal, -5)
                .offset(y: -15)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressing)
            }
        }
    }
}

struct TrackRow: View {
    let track: Track
    @State private var showDetails = false
    @State private var selectedFrame: CGRect = .zero
    
    private var formattedTimestamp: String {
        guard let playedAt = track.playedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: playedAt, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showDetails = true
            }
        }) {
            HStack(spacing: 12) {
                TrackArtworkView(imageUrl: track.album.imageUrl)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: FramePreferenceKey.self,
                                value: geometry.frame(in: .global)
                            )
                        }
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                    Text(track.artists.first?.name ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    if !formattedTimestamp.isEmpty {
                        Text(formattedTimestamp)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .onPreferenceChange(FramePreferenceKey.self) { frame in
            selectedFrame = frame
        }
        .fullScreenCover(isPresented: $showDetails) {
            TrackDetailView(track: track, sourceFrame: selectedFrame)
        }
    }
}

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct TrackDetailView: View {
    let track: Track
    let sourceFrame: CGRect
    @Environment(\.dismiss) private var dismiss
    @State private var offset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private var formattedDuration: String {
        guard let durationMs = track.durationMs else { return "Unknown" }
        let minutes = durationMs / 60000
        let seconds = (durationMs % 60000) / 1000
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedReleaseDate: String {
        guard let releaseDate = track.album.releaseDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: releaseDate)
    }
    
    private func dismissView() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = UIScreen.main.bounds.height
        }
        dismiss()
    }
    
    var body: some View {
        ZStack {
            // Modal content
            VStack(spacing: 20) {
                // Album Art
                AsyncImage(url: URL(string: track.album.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
                
                // Track Info
                VStack(spacing: 8) {
                    Text(track.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(track.artists.first?.name ?? "")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    if track.explicit == true {
                        Text("Explicit")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                // Album Info
                VStack(spacing: 4) {
                    Text("From the album")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(track.album.name)
                        .font(.headline)
                }
                
                // Additional Info
                VStack(spacing: 12) {
                    InfoRow(title: "Duration", value: formattedDuration)
                    InfoRow(title: "Release Date", value: formattedReleaseDate)
                    InfoRow(title: "Popularity", value: "\(track.popularity ?? 0)%")
                }
                .padding(.top)
                
                Spacer()
                
                // Dismiss Button
                Button(action: dismissView) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding()
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
                .padding(.bottom, 20)
            }
            .padding()
        }
        .presentationBackground(.ultraThinMaterial)
        .offset(y: offset + dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    isDragging = false
                    if value.translation.height > 100 {
                        dismissView()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                offset = 0
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
}

struct ArtistCard: View {
    let artist: Artist
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: artist.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            Text(artist.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 90)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(height: 120, alignment: .top)
        .padding(.top, 8)
    }
}

struct TrackArtworkView: View {
    let imageUrl: String?
    
    var body: some View {
        AsyncImage(url: URL(string: imageUrl ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "music.note")
        }
        .frame(width: 50, height: 50)
        .cornerRadius(4)
    }
}

struct UserProfileButton: View {
    let userProfile: UserProfile?
    let onSignOut: () -> Void
    
    var body: some View {
        Menu {
            Button(role: .destructive, action: onSignOut) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            if let imageUrl = userProfile?.images?.first?.url {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

// First, let's create a new view for the fixed header
struct HeaderView: View {
    let artists: [Artist]
    let selectedTab: Binding<Int>
    let onLoadMore: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Top Artists Section
            ArtistsSection(
                title: "Top Artists",
                artists: artists,
                onLoadMore: onLoadMore
            )
            
            // Tracks Section Picker
            Picker("Track View", selection: selectedTab) {
                Text("Recently Played").tag(0)
                Text("Top Tracks").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

// Create a view for the scrollable content
struct TracksContentView: View {
    let selectedTab: Int
    let recentlyPlayed: [PlayHistoryItem]
    let topTracks: [Track]
    let onLoadMoreRecent: () async -> Void
    let onLoadMoreTop: () async -> Void
    
    var body: some View {
        if selectedTab == 0 {
            ActivitySection(
                title: nil,
                items: recentlyPlayed.map { item in
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
                },
                onLoadMore: onLoadMoreRecent
            )
        } else {
            ActivitySection(
                title: nil,
                items: topTracks,
                onLoadMore: onLoadMoreTop
            )
        }
        // .padding()
    }
}

// Update the main content view
struct MainContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header
            HeaderView(
                artists: viewModel.topArtists,
                selectedTab: $selectedTab,
                onLoadMore: {
                    await viewModel.loadMoreTopArtists()
                }
            )
            
            // Scrollable Content
            ScrollView {
                TracksContentView(
                    selectedTab: selectedTab,
                    recentlyPlayed: viewModel.recentlyPlayed,
                    topTracks: viewModel.topTracks,
                    onLoadMoreRecent: {
                        await viewModel.loadMoreRecentlyPlayed()
                    },
                    onLoadMoreTop: {
                        await viewModel.loadMoreTopTracks()
                    }
                )
            }
        }
    }
}
