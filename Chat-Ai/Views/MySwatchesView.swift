//
//  MySwatchesView.swift
//  Chat-Ai
//
//  Màn My Swatches list với tabs (My Swatches / Favorites)
//  UI theo Figma node 55478-1814
//

import SwiftUI

struct MySwatchesView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = MySwatchesViewModel()
    @StateObject private var subscriptionViewModel = SubscriptionViewModel.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                    mainContent
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await viewModel.loadSwatches()
        }
    }

    // MARK: - Header (Figma: logo trái, tabs giữa, avatar phải)

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Logo bên trái (23x23)
            Image("logo_small")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)

            Spacer()

            // Tab switcher ở giữa
            tabSwitcher

            Spacer()

            // Profile avatar với badge
            NavigationLink(destination: ProfileView()) {
                profileAvatarWithBadge
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 16) {
            tabButton(.mySwatches)
            tabButton(.saved)
        }
    }

    private func tabButton(_ tab: SwatchTab) -> some View {
        Button(action: {
            Task { await viewModel.switchTab(to: tab) }
        }) {
            VStack(spacing: 4) {
                Text(tab.title)
                    .font(.custom("Overused Grotesk", size: 14).weight(viewModel.selectedTab == tab ? .bold : .medium))
                    .foregroundColor(viewModel.selectedTab == tab ? Color(hex: "101828") : Color(hex: "6A7282"))

                // Underline indicator - chỉ rộng bằng text
                Rectangle()
                    .fill(viewModel.selectedTab == tab ? Color(hex: "101828") : Color.clear)
                    .frame(height: 2)
            }
            .fixedSize(horizontal: true, vertical: false) // Không flex, chỉ rộng bằng content
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var profileAvatarWithBadge: some View {
        ZStack(alignment: .bottom) {
            avatarImage
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            // Badge Pro/Free
            Group {
                if subscriptionViewModel.hasPremiumAccess() {
                    HStack(spacing: 3) {
                        Image("pro_badge_crown")
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 10, height: 8)
                        Text("PRO")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black)
                    .clipShape(Capsule())
                } else {
                    Text("Free")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
            }
            .offset(y: 8)
        }
        .frame(width: 40, height: 48)
    }

    private var avatarImage: some View {
        Group {
            if let urlString = authViewModel.currentUser?.avatarURL,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(width: 40, height: 40)
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "6A7282"))
                    @unknown default:
                        Color(hex: "E4E4E4")
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "6A7282"))
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.swatches.isEmpty {
                emptyStateView
            } else {
                swatchList
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.custom("Overused Grotesk", size: 14))
                .foregroundColor(Color(hex: "6A7282"))
                .padding(.top, 16)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "F97316"))
            Text(message)
                .font(.custom("Overused Grotesk", size: 14))
                .foregroundColor(Color(hex: "6A7282"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: {
                Task { await viewModel.refresh() }
            }) {
                Text("Try Again")
                    .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(hex: "030712"))
                    .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: viewModel.selectedTab == .mySwatches ? "photo.on.rectangle.angled" : "heart")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "D1D5DB"))
            Text(viewModel.selectedTab == .mySwatches ? "No swatches yet" : "No saved swatches")
                .font(.custom("Overused Grotesk", size: 18).weight(.medium))
                .foregroundColor(Color(hex: "101828"))
            Text(viewModel.selectedTab == .mySwatches
                 ? "Start swatching to see your history here"
                 : "Tap the heart icon on any swatch to save it")
                .font(.custom("Overused Grotesk", size: 14))
                .foregroundColor(Color(hex: "6A7282"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var swatchList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.swatches) { swatch in
                    NavigationLink(destination: SwatchDetailView(swatch: swatch, viewModel: viewModel)) {
                        SwatchCardView(
                            swatch: swatch,
                            onFavoriteToggle: {
                                Task { await viewModel.toggleFavorite(swatch: swatch) }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentItem: swatch) }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100) // Space for tab bar
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Swatch Card View (Figma: full width - 40px padding, height 447, corner 16)

struct SwatchCardView: View {
    let swatch: Swatch
    let onFavoriteToggle: () -> Void

    private let cardHeight: CGFloat = 447
    private let cornerRadius: CGFloat = 16
    private let contentPadding: CGFloat = 16

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background image (swatch result)
            swatchImage

            // Content overlay at bottom
            VStack {
                Spacer()
                contentOverlay
            }

            // Favorite button (top right)
            favoriteButton
                .padding(contentPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(Color(hex: "F3F4F6"))
        .cornerRadius(cornerRadius)
    }

    private var swatchImage: some View {
        GeometryReader { geo in
            Group {
                if let swatchUrl = swatch.swatchUrl, let url = URL(string: swatchUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: cardHeight)
                                .clipped()
                        case .failure:
                            placeholderContent
                        case .empty:
                            ZStack {
                                Color(hex: "F3F4F6")
                                ProgressView()
                            }
                        @unknown default:
                            placeholderContent
                        }
                    }
                } else {
                    placeholderContent
                }
            }
            .frame(width: geo.size.width, height: cardHeight)
        }
        .frame(height: cardHeight)
        .cornerRadius(cornerRadius)
    }

    private var placeholderContent: some View {
        ZStack {
            Color(hex: "F3F4F6")
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "D1D5DB"))
        }
    }

    private var placeholderImage: some View {
        placeholderContent
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
    }

    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(swatch.displayName)
                .font(.custom("Overused Grotesk", size: 20).weight(.medium))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(swatch.brand)
                    .font(.custom("Overused Grotesk", size: 14))
                    .foregroundColor(.white.opacity(0.8))

                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)

                Text(swatch.timeAgoString)
                    .font(.custom("Overused Grotesk", size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(contentPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(cornerRadius, corners: [.bottomLeft, .bottomRight])
    }

    private var favoriteButton: some View {
        Button(action: onFavoriteToggle) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: swatch.isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(swatch.isFavorited ? Color(hex: "EF4444") : .white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MySwatchesView()
        .environmentObject(AuthViewModel())
}
