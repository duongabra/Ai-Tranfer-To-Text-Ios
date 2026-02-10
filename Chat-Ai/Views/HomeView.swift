//
//  HomeView.swift
//  Chat-Ai
//
//  Màn Home - AI Lipstick Swatching (UI theo Figma node 55367-1228)
//

import SwiftUI

private enum HomeConstants {
    /// Before (trái) – ảnh chưa son
    static let placeholderBeforeImageURL = "https://static.wikia.nocookie.net/meangirls/images/2/27/Amanda_Seyfried.jpg/revision/latest?cb=20240901225458"
    /// After (phải) – ảnh đã thử son (placeholder: có thể thay URL thật)
    static let placeholderAfterImageURL = "https://static.wikia.nocookie.net/meangirls/images/2/27/Amanda_Seyfried.jpg/revision/latest?cb=20240901225458"
    static let cardCornerRadius: CGFloat = 16
    static let badgeBlur: CGFloat = 8
}

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var subscriptionViewModel = SubscriptionViewModel.shared

    /// Tên hiển thị: ưu tiên last_name, không có thì first_name, không có cả hai thì "Beauty"
    private var greetingName: String {
        guard let user = authViewModel.currentUser else { return "Beauty" }
        let first = (user.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let last = (user.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { return last }
        if !first.isEmpty { return first }
        return "Beauty"
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection

                    // Greeting + CTA (Figma Frame 1000009112): centered, gap 24
                    greetingAndCTABlock

                    // Main card: Before/After images only (Figma Frame 1000009111 area)
                    mainCardSection
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task { await subscriptionViewModel.loadSubscriptionStatus(forceRefresh: true) }
        }
    }

    // MARK: - Header (Figma: logo trái, avatar + badge phải – avatar giữ nguyên)
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 127, height: 24)
                .clipped()

            Spacer(minLength: 0)

            // Avatar + badge Pro/Free: bấm vào → Profile (tab bar sẽ ẩn khi ở màn Profile)
            NavigationLink(destination: ProfileView()) {
                ZStack {
                    VStack(alignment: .center, spacing: 0) {
                        avatarView
                        Group {
                            if subscriptionViewModel.hasPremiumAccess() {
                                HStack(spacing: 3) {
                                    Image("pro_badge_crown")
                                        .renderingMode(.template)
                                        .foregroundColor(.white)
                                        .frame(width: 10, height: 8)
                                    Text("PRO")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(EdgeInsets(top: 4, leading: 8, bottom: 2, trailing: 8))
                                .background(Color.black)
                                .clipShape(Capsule())
                            } else {
                                Text("Free")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(EdgeInsets(top: 4, leading: 8, bottom: 2, trailing: 8))
                                    .background(Color.black)
                                    .clipShape(Capsule())
                            }
                        }
                        .offset(y: -10)
                    }
                    .frame(width: 50, height: 55)
                    .scaleEffect(50 / 55)
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
    }

    // MARK: - Greeting + CTA (Figma 1000009112): 2 lines, centered
    private var greetingAndCTABlock: some View {
        VStack(alignment: .center, spacing: 24) {
            VStack(alignment: .center, spacing: 0) {
                Text("👋 Hi, \(greetingName)! Are you")
                    .font(.custom("Overused Grotesk", size: 28).weight(.medium))
                    .foregroundColor(Color(hex: "101828"))
                    .multilineTextAlignment(.center)
                Text("ready to swatch today?")
                    .font(.custom("Overused Grotesk", size: 28).weight(.medium))
                    .foregroundColor(Color(hex: "101828"))
                    .multilineTextAlignment(.center)
            }
            .lineSpacing(36 - 28)

            NavigationLink(destination: SwatchUploadView()) {
                HStack(spacing: 8) {
                    Image("lipstick_icon")
                        .renderingMode(.template)
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(width: 20, height: 20)
                        .clipped()
                    Text("Start Swatching")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                }
                .foregroundColor(Color(hex: "F9FAFB"))
                .padding(EdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 32))
                .background(Color(hex: "030712"))
                .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    /// Avatar lấy từ Supabase: bảng user_profiles, cột avatar_url (load qua AuthViewModel.loadUserInfoFromDB).
    private var avatarView: some View {
        Group {
            if let urlString = authViewModel.currentUser?.avatarURL,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 40, height: 40)
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "6A7282"))
                    @unknown default:
                        Color(hex: "E4E4E4")
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            } else {
                // Chưa có avatar_url trong Supabase hoặc đang load
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "6A7282"))
            }
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Main card: two 150×180 cards (Figma 1000009111)
    private static let cardWidth: CGFloat = 150
    private static let cardHeight: CGFloat = 180

    private var mainCardSection: some View {
        HStack(spacing: 12) {
            beforeAfterCard(
                urlString: HomeConstants.placeholderBeforeImageURL,
                label: "Before"
            )
            beforeAfterCard(
                urlString: HomeConstants.placeholderAfterImageURL,
                label: "After"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private static let cardInnerPadding: CGFloat = 4

    private func beforeAfterCard(urlString: String, label: String) -> some View {
        let innerW = Self.cardWidth - Self.cardInnerPadding * 2
        let innerH = Self.cardHeight - Self.cardInnerPadding * 2
        return ZStack(alignment: .topLeading) {
            Color.white

            Group {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Color(hex: "E4E4E4")
                        }
                    }
                }
            }
            .frame(width: innerW, height: innerH)
            .clipped()
            .cornerRadius(HomeConstants.cardCornerRadius - 1)
            .padding(Self.cardInnerPadding)

            badgeLabel(text: label)
                .padding(8 + Self.cardInnerPadding)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .cornerRadius(HomeConstants.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: HomeConstants.cardCornerRadius)
                .stroke(Color(hex: "E4E4E4"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private func badgeLabel(text: String) -> some View {
        Text(text)
            .font(.custom("Overused Grotesk", size: 11).weight(.medium))
            .foregroundColor(Color(hex: "101828"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(9999)
            .overlay(
                RoundedRectangle(cornerRadius: 9999)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationView {
        HomeView()
            .environmentObject(AuthViewModel())
    }
}
