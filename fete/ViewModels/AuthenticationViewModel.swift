import Foundation
import Combine
import SwiftUI

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSpotifyAuthObservers()
    }
    
    private func setupSpotifyAuthObservers() {
        SpotifyAuthManager.shared.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
    }
    
    func signInWithSpotify() {
        SpotifyAuthManager.shared.authenticate()
    }
} 
