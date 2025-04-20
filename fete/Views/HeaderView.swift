import SwiftUI

enum ScrollToTop {
    case tracks
}

struct HeaderView: View {
    // Properties
    let artists: [Artist]
    let selectedTab: Binding<Int>
    let onLoadMore: () async -> Void
    let scrollProxy: ScrollViewProxy
    @GestureState private var isLongPressing = false
    @State private var selectedTabScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 10) {
            ArtistsSection(
                title: "Top Artists",
                artists: artists,
                onLoadMore: onLoadMore
            )

            CustomTabPicker(
                selectedTab: selectedTab,
                selectedTabScale: $selectedTabScale,
                scrollProxy: scrollProxy
            )
        }
        .padding(.top)
        .background(Color(UIColor.systemBackground))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressing)
    }
}

private struct CustomTabPicker: View {
    let selectedTab: Binding<Int>
    @Binding var selectedTabScale: CGFloat
    let scrollProxy: ScrollViewProxy

    var body: some View {
        ZStack {
            // Parent background with inner and outer shadows
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemGray6)
                .shadow(.inner(color: .black.opacity(0.1), radius: 2)))
                

            // Tab buttons container
            TabButtons(
                selectedTab: selectedTab,
                selectedTabScale: $selectedTabScale,
                scrollProxy: scrollProxy
            )
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
    }
}

private struct TabButtons: View {
    let selectedTab: Binding<Int>
    @Binding var selectedTabScale: CGFloat
    let scrollProxy: ScrollViewProxy

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<2) { index in
                TabButton(
                    index: index,
                    selectedTab: selectedTab,
                    selectedTabScale: $selectedTabScale,
                    scrollProxy: scrollProxy
                )
            }
        }
        .background(
            SliderBackground(selectedTab: selectedTab.wrappedValue)
        )
    }
}

private struct TabButton: View {
    let index: Int
    let selectedTab: Binding<Int>
    @GestureState private var isLongPressing = false 
    @Binding var selectedTabScale: CGFloat
    let scrollProxy: ScrollViewProxy

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab.wrappedValue = index
            }
        }) {
            Text(index == 0 ? "Recently Played" : "Top Tracks")
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedTab.wrappedValue == index ? .white : .primary)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .updating($isLongPressing) { currentState, gestureState, _ in
                    gestureState = currentState
                    if selectedTab.wrappedValue == index {
                        animateTabScale()
                    }
                }
                .onEnded { _ in
                    if selectedTab.wrappedValue == index {
                        withAnimation {
                            scrollProxy.scrollTo(ScrollToTop.tracks, anchor: .top)
                        }
                    }
                }
        )
        .scaleEffect(selectedTab.wrappedValue == index ? selectedTabScale : 1.0)
    }

    private func animateTabScale() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            selectedTabScale = 0.95
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                selectedTabScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    selectedTabScale = 1.0
                }
            }
        }
    }
}

private struct SliderBackground: View {
    let selectedTab: Int

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.9),
                            Color.accentColor
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 2)
                .frame(
                    width: (geometry.size.width / 2) - 1,
                    height: geometry.size.height + 2
                )
                .position(
                    x: (geometry.size.width / 4) + CGFloat(selectedTab)
                        * (geometry.size.width / 2),
                    y: geometry.size.height / 2
                )
        }
    }
}

#Preview {
    ScrollViewReader { proxy in
        HeaderView(
            artists: [
                Artist(id: "1", uri: "spotify:artist:1", name: "Artist 1", images: nil),
                Artist(id: "2", uri: "spotify:artist:2", name: "Artist 2", images: nil)
            ],
            selectedTab: .constant(0),
            onLoadMore: { },
            scrollProxy: proxy
        )
    }
}