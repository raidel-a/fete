import SwiftUI

// MARK: - Track Row
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
                }

                Spacer(minLength: 12)

                if !formattedTimestamp.isEmpty {
                    Text(formattedTimestamp)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(alignment: .trailing)
                }
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

// MARK: - Track Artwork View
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

// MARK: - Track Detail View
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
            VStack(spacing: 20) {
                AsyncImage(url: URL(string: track.album.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }

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

                VStack(spacing: 4) {
                    Text("From the album")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(track.album.name)
                        .font(.headline)
                }

                VStack(spacing: 12) {
                    InfoRow(title: "Duration", value: formattedDuration)
                    InfoRow(title: "Release Date", value: formattedReleaseDate)
                    InfoRow(title: "Popularity", value: "\(track.popularity ?? 0)%")
                }
                .padding(.top)

                Spacer()

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

// MARK: - Supporting Views
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

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    TrackRow(track: Track(
        id: "preview",
        uri: "spotify:track:preview",
        name: "Preview Track",
        artists: [
            Artist(id: "1", uri: "spotify:artist:1", name: "Preview Artist", images: nil)
        ],
        album: Album(
            id: "1",
            uri: "spotify:album:1",
            name: "Preview Album",
            images: [],
            releaseDate: Date(),
            totalTracks: 1,
            albumType: "album"
        ),
        context: nil,
        position: 0,
        durationMs: 180000,
        popularity: 80,
        explicit: true,
        playedAt: Date(),
        previewUrl: nil
    ))
    .padding()
}