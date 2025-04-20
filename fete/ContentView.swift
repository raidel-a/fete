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
                throw NSError(
                    domain: "ContentViewModel", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No access token available"])
            }

            self.userProfile = try await SpotifyActivityService.shared.fetchUserProfile(
                accessToken: accessToken)
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
    
    func refreshRecentlyPlayed() async {
        // Reset pagination state for recently played
        canLoadMoreRecentlyPlayed = true
        lastRecentlyPlayedTimestamp = nil
        recentlyPlayed = []
        
        // Load first page
        await loadMoreRecentlyPlayed()
    }
    
    func refreshTopTracks() async {
        // Reset pagination state for top tracks
        canLoadMoreTopTracks = true
        topTracksOffset = 0
        topTracks = []
        
        // Load first page
        await loadMoreTopTracks()
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
                            ErrorView(
                                error: error,
                                retryAction: {
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
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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

