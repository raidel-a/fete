import SwiftUI

// MARK: - Artists Section
struct ArtistsSection: View {
    let title: String
    let artists: [Artist]
    var onLoadMore: (() async -> Void)?
    @State private var isLoadingMore = false
    @State private var currentPage = 0
    @GestureState private var dragOffset: CGFloat = 0

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
                ArtistsPager(
                    artists: artists,
                    currentPage: $currentPage,
                    dragOffset: dragOffset,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    cardSpacing: cardSpacing,
                    cardsPerPage: cardsPerPage,
                    onLoadMore: onLoadMore,
                    isLoadingMore: $isLoadingMore
                )

                NavigationControls(
                    currentPage: $currentPage,
                    numberOfPages: numberOfPages,
                    dragOffset: dragOffset,
                    borderRadius: borderRadius,
                    onLoadMore: onLoadMore,
                    isLoadingMore: $isLoadingMore
                )
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Artists Pager
private struct ArtistsPager: View {
    let artists: [Artist]
    @Binding var currentPage: Int
    let dragOffset: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let cardSpacing: CGFloat
    let cardsPerPage: Int
    var onLoadMore: (() async -> Void)?
    @Binding var isLoadingMore: Bool
    @State private var offset: CGFloat = 0
    @GestureState private var dragState = CGSize.zero

    private var numberOfPages: Int {
        (artists.count + cardsPerPage - 1) / cardsPerPage
    }

    var body: some View {
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
                            }
                        }
                    }
                    .frame(width: geometry.size.width)
                }
            }
            .offset(x: -CGFloat(currentPage) * geometry.size.width + dragState.width)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            .gesture(
                DragGesture()
                    .updating($dragState) { value, state, _ in
                        state = CGSize(width: value.translation.width, height: 0)
                    }
                    .onEnded { value in
                        let threshold = geometry.size.width * 0.3
                        let offset = value.translation.width
                        let predictedOffset = value.predictedEndTranslation.width
                        
                        var newPage = currentPage
                        
                        // Determine direction based on gesture
                        if abs(offset) > threshold || abs(predictedOffset) > threshold {
                            newPage = offset > 0 ? currentPage - 1 : currentPage + 1
                        }
                        
                        // Ensure newPage is within bounds
                        newPage = max(0, min(numberOfPages - 1, newPage))
                        
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
    }
}

// MARK: - Navigation Controls
private struct NavigationControls: View {
    @Binding var currentPage: Int
    let numberOfPages: Int
    let dragOffset: CGFloat
    let borderRadius: CGFloat
    var onLoadMore: (() async -> Void)?
    @Binding var isLoadingMore: Bool

    var body: some View {
        HStack {
            NavigationButton(
                direction: .previous,
                currentPage: $currentPage,
                numberOfPages: numberOfPages,
                dragOffset: dragOffset,
                borderRadius: borderRadius
            )

            Spacer()

            NavigationButton(
                direction: .next,
                currentPage: $currentPage,
                numberOfPages: numberOfPages,
                dragOffset: dragOffset,
                borderRadius: borderRadius,
                onLoadMore: onLoadMore,
                isLoadingMore: $isLoadingMore
            )
        }
        .padding(.horizontal)
        .offset(y: -20)
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: currentPage)
    }
}

// MARK: - Navigation Button
private struct NavigationButton: View {
    enum Direction {
        case previous, next
    }

    let direction: Direction
    @Binding var currentPage: Int
    let numberOfPages: Int
    @GestureState private var isLongPressingLocal = false
    let borderRadius: CGFloat
    var onLoadMore: (() async -> Void)?
    @Binding var isLoadingMore: Bool

    init(
        direction: Direction,
        currentPage: Binding<Int>,
        numberOfPages: Int,
        dragOffset: CGFloat,
        borderRadius: CGFloat,
        onLoadMore: (() async -> Void)? = nil,
        isLoadingMore: Binding<Bool> = .constant(false)
    ) {
        self.direction = direction
        self._currentPage = currentPage
        self.numberOfPages = numberOfPages
        self.borderRadius = borderRadius
        self.onLoadMore = onLoadMore
        self._isLoadingMore = isLoadingMore
    }

    private var isEnabled: Bool {
        switch direction {
        case .previous: return currentPage > 0
        case .next: return currentPage < numberOfPages - 1
        }
    }

    var body: some View {
        Group {
            if isEnabled {
                Button(action: handleButtonTap) {
                    createButtonContent()
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1.0)
                        .updating($isLongPressingLocal) { currentState, gestureState, _ in
                            gestureState = true
                        }
                        .onEnded { _ in
                            if direction == .previous {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    currentPage = 0
                                }
                            }
                        }
                )
                .transition(.opacity)
            } else {
                createDisabledButton()
            }
        }
    }

    private func handleButtonTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            switch direction {
            case .previous:
                if isLongPressingLocal {
                    currentPage = 0
                } else {
                    currentPage = max(0, currentPage - 1)
                }
            case .next:
                let newPage = min(numberOfPages - 1, currentPage + 1)
                currentPage = newPage
                if newPage == numberOfPages - 1 && !isLoadingMore {
                    Task {
                        isLoadingMore = true
                        await onLoadMore?()
                        isLoadingMore = false
                    }
                }
            }
        }
    }

    private func createButtonContent() -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.0))
            .frame(width: 23, height: 30)
            .cornerRadius(borderRadius)
            .overlay(
                Image(
                    systemName: direction == .previous && isLongPressingLocal  // Changed to isLongPressingLocal
                        ? "chevron.backward.chevron.backward.circle"
                        : direction == .previous ? "chevron.compact.left" : "chevron.compact.right"
                )
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black.opacity(0.4))
                .shadow(radius: 20)
            )
    }

    private func createDisabledButton() -> some View {
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
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity.combined(with: .scale)
                ))
    }
}

// MARK: - Artist Card
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
            // .overlay(
            //     ZStack {
            //         // Vertical line extending beyond circle
            //         Rectangle()
            //             .fill(Color.red)
            //             .frame(width: 1, height: 200)
            //         // Horizontal line extending beyond circle
            //         Rectangle()
            //             .fill(Color.red)
            //             .frame(width: 200, height: 1)
            //     }
            // )

            Text(artist.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 90)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(height: 120, alignment: .top)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview {
    ArtistsSection(
        title: "Top Artists",
        artists: [
            Artist(id: "1", uri: "spotify:artist:1", name: "Artist 1", images: nil),
            Artist(id: "2", uri: "spotify:artist:2", name: "Artist 2", images: nil),
            Artist(id: "3", uri: "spotify:artist:3", name: "Artist 3", images: nil),
            Artist(id: "4", uri: "spotify:artist:4", name: "Artist 4", images: nil),
        ]
    )
    .padding()
}
