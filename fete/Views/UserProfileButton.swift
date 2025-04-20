import SwiftUI

struct UserProfileButton: View {
    let userProfile: UserProfile?
    let onSignOut: () -> Void
    @State private var showingProfile = false
    
    var body: some View {
        Button {
            showingProfile = true
        } label: {
            if let imageUrl = userProfile?.images?.first?.url {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.primary, lineWidth: 2)
                        .padding(-3)
                )
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
            }
        }
        .confirmationDialog("Profile Options", isPresented: $showingProfile) {
            Button("Sign Out", role: .destructive, action: onSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(userProfile?.displayName ?? "Profile Options")
        }
    }
}

#Preview {
    UserProfileButton(
        userProfile: UserProfile(
            id: "1",
            displayName: "Test User",
            images: [
                UserProfile.ProfileImage(
                    url: "https://example.com/image.jpg",
                    height: 64,
                    width: 64
                )
            ],
            email: "test@example.com",
            product: "premium"
        ),
        onSignOut: {}
    )
}