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
    static let cardCornerRadius: CGFloat = 12
    static let badgeBlur: CGFloat = 8
}

// MARK: - Mock data cho Recent Swatches (theo Figma)
private struct SwatchItem: Identifiable {
    let id = UUID()
    let brand: String
    let timeAgo: String
    let productName: String
    let colorName: String
    let colorHex: Color
}

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    /// Tên hiển thị: ưu tiên last_name, không có thì first_name, không có cả hai thì "Beauty"
    private var greetingName: String {
        guard let user = authViewModel.currentUser else { return "Beauty" }
        let first = (user.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let last = (user.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { return last }
        if !first.isEmpty { return first }
        return "Beauty"
    }

    private static let recentSwatches: [SwatchItem] = [
        SwatchItem(brand: "MAC", timeAgo: "2 days ago", productName: "Silky Matte Lipstick", colorName: "Get The Hint", colorHex: Color(hex: "D55560")),
        SwatchItem(brand: "DIOR", timeAgo: "3 days ago", productName: "Rouge Dior On Stage", colorName: "425 Wild Rosewood", colorHex: Color(hex: "910904")),
        SwatchItem(brand: "YSL", timeAgo: "4 days ago", productName: "Candy Glaze Lip Gloss Stick", colorName: "14 - Scenic Brown", colorHex: Color(hex: "9D3B39")),
        SwatchItem(brand: "CHANEL", timeAgo: "5 days ago", productName: "Rough Coco Baume", colorName: "920 In Love", colorHex: Color(hex: "CA878D"))
    ]

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Header (Hi + subtitle, avatar tap → Paywall)
                    headerSection

                    // MARK: - Main card (image Before/After + title + Start Swatching)
                    mainCardSection

                    // MARK: - Recent Swatches
                    recentSwatchesSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hi, \(greetingName)! 👋")
                    .font(.custom("Overused Grotesk", size: 28).weight(.regular))
                    .foregroundColor(Color(hex: "020202"))
                    .lineSpacing(36 - 28)

                Text("Which swatch do you wanna today?")
                    .font(.custom("Overused Grotesk", size: 16).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
                    .lineSpacing(24 - 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Avatar từ Supabase user_profiles.avatar_url; bấm vào → Paywall
            NavigationLink(destination: PaywallView()) {
                avatarView
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .padding(.horizontal, 0)
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

    // MARK: - Main card: w = 1/2 provider (mỗi nửa ảnh), h = w (chiều cao khối = nửa width)
    private var mainCardSection: some View {
        VStack(alignment: .center, spacing: 0) {
            GeometryReader { geo in
                let totalW = geo.size.width
                let w = totalW / 2   // mỗi nửa rộng 1/2 provider
                let h = w            // h = w
                ZStack(alignment: .top) {
                    imageRow(height: h)
                    HStack {
                        badgeLabel(text: "Before")
                        Spacer()
                        badgeLabel(text: "After")
                    }
                    .padding(8)
                }
                .frame(width: totalW, height: h)
                .clipped()
            }
            .aspectRatio(2, contentMode: .fit)

            // Title + button (cách khối ảnh 16px, có padding bên dưới)
            VStack(spacing: 12) {
                Text("Try On Any Lipsticks")
                    .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(32 - 24)

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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.leading, 10)
                    .padding(.trailing, 20)
                    .background(Color(hex: "030712"))
                    .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.black.opacity(0.03))
        .cornerRadius(HomeConstants.cardCornerRadius)
    }

    /// Hai ảnh chia đôi: mỗi nửa w = 1/2 provider, h = w; cách nhau 1px trắng
    private func imageRow(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            halfImage(urlString: HomeConstants.placeholderBeforeImageURL, height: height)
            Color.white.frame(width: 1)
            halfImage(urlString: HomeConstants.placeholderAfterImageURL, height: height)
        }
        .frame(height: height)
        .cornerRadius(HomeConstants.cardCornerRadius)
    }

    private func halfImage(urlString: String, height: CGFloat) -> some View {
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
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
            }
        }
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

    // MARK: - Recent Swatches
    private var recentSwatchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Swatches")
                .font(.custom("Overused Grotesk", size: 18).weight(.medium))
                .foregroundColor(Color(hex: "364153"))
                .lineSpacing(28 - 18)

            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(HomeView.recentSwatches.prefix(2))) { item in
                        swatchCard(item: item)
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(HomeView.recentSwatches.suffix(2))) { item in
                        swatchCard(item: item)
                    }
                }
            }
        }
    }

    private func swatchCard(item: SwatchItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.brand)
                    .font(.custom("Overused Grotesk", size: 12).weight(.medium))
                    .foregroundColor(Color(hex: "6A7282"))
                Spacer()
                Text(item.timeAgo)
                    .font(.custom("Overused Grotesk", size: 11).weight(.regular))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            Text(item.productName)
                .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "101828"))
                .lineLimit(2)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.colorHex)
                    .frame(width: 12, height: 12)
                Text(item.colorName)
                    .font(.custom("Overused Grotesk", size: 12).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E4E4E4"), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        HomeView()
            .environmentObject(AuthViewModel())
    }
}
