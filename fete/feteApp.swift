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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
