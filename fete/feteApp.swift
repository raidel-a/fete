//
//  feteApp.swift
//  fete
//
//  Created by Raidel Almeida on 4/3/25.
//

import SwiftUI
import SwiftData

@main
struct feteApp: App {
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                SpotifyLoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
