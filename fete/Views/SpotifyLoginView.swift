import SwiftUI
import Combine
import AuthenticationServices

struct SpotifyLoginView: View {
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        GeometryReader { geometry in
//            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    // Logo and App Name
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.house.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.green)
                        
                        Text("Fete")
                            .font(.system(size: 42, weight: .bold))
                        Text("Listen Together")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 15) {
                        FeatureRow(icon: "person.2.fill", text: "See what your friends are listening to")
                        FeatureRow(icon: "music.note.list", text: "Create and join jam sessions")
                        FeatureRow(icon: "hand.raised.fill", text: "Share your music taste")
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Connect Button
                    Button {
                        authViewModel.signInWithSpotify()
                    } label: {
                        HStack {
                            Image(systemName: "music.note")
                                .resizable()
                                .frame(width: 16 , height: 24)
                            Text("Connect with Spotify")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 40)
                    
                    // Terms and Privacy
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                        .padding(.bottom)
                }
                .frame(minHeight: geometry.size.height)
                .padding()
//            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                             to: nil, 
                                             from: nil, 
                                             for: nil)
            }
        }
    }
}

//struct FeatureRow: View {
//    let icon: String
//    let text: String
//    
//    var body: some View {
//        HStack(spacing: 15) {
//            Image(systemName: icon)
//                .foregroundColor(.green)
//                .font(.title2)
//            Text(text)
//                .font(.body)
//        }
//    }
//}

#Preview {
    SpotifyLoginView()
        .environmentObject(AuthenticationViewModel())
} 
