//
//  HomeView.swift
//  Chat-Ai
//
//  Màn hình Home sau khi login
//

import SwiftUI

struct HomeView: View {
    @State private var hasActiveSubscription = false
    @State private var isLoadingSubscription = true
    
    var body: some View {
        ZStack {
            // Background
            Color.backgroundCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                homeHeader
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Title Section
                        titleSection
                        
                        // Action Cards
                        actionCardsSection
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Header
    
    private var homeHeader: some View {
        HStack {
            // Menu icon (3 gạch ngang)
            Button(action: {
                // TODO: Open menu drawer
            }) {
                MenuIcon()
                    .frame(width: 40, height: 40)
            }
            
            Spacer()
            
            // Subscription Badge
            SubscriptionBadge(isPro: hasActiveSubscription)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Welcome to VidSum")
                .font(.headingLarge)
                .lineSpacing(36 - 28) // line-height 36px - font-size 28px = 8px
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Upload a video or audio file, or paste a YouTube/X link to get started")
                .font(.bodyMedium)
                .lineSpacing(19.6 - 14) // line-height 19.6px - font-size 14px = 5.6px
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Action Cards Section
    
    private var actionCardsSection: some View {
        HStack(spacing: 16) {
            // Upload File Card
            ActionCard(
                icon: "upload_3_line",
                title: "Upload File",
                subtitle: "Upload Audio or Video",
                backgroundColor: Color.primaryOrange.opacity(0.1),
                iconColor: .primaryOrange
            ) {
                // TODO: Handle upload file
                print("Upload file tapped")
            }
            
            // Paste Link Card
            ActionCard(
                icon: "link_2_line",
                title: "Paste Link",
                subtitle: "YouTube or X video URL",
                backgroundColor: Color(hex: "FF920A").opacity(0.1),
                iconColor: Color(hex: "FF920A")
            ) {
                // TODO: Handle paste link
                print("Paste link tapped")
            }
        }
        .frame(maxWidth: 358)
    }
    
    // MARK: - Helper Methods
    
    private func checkSubscriptionStatus() async {
        isLoadingSubscription = true
        hasActiveSubscription = await RevenueCatService.shared.hasActiveSubscription()
        isLoadingSubscription = false
    }
}

// MARK: - Subscription Badge

struct SubscriptionBadge: View {
    let isPro: Bool
    
    var body: some View {
        if isPro {
            // Pro Badge (ảnh 2)
            HStack(spacing: 4) {
                Text("Pro")
                    .font(.labelMedium)
                    .foregroundColor(.white)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primaryOrange)
            .cornerRadius(9999)
        } else {
            // Upgrade Badge (ảnh 1)
            HStack(spacing: 4) {
                Text("Upgrade")
                    .font(.labelMedium)
                    .foregroundColor(.primaryOrange)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primaryOrange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primaryOrange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 9999)
                    .stroke(Color.primaryOrange.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(9999)
        }
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon - sử dụng ảnh từ Assets
                if icon == "upload_3_line" {
                    Image("upload")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                } else if icon == "link_2_line" {
                    Image("paste_link")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                        .frame(width: 48, height: 48)
                        .background(iconColor.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Text
                VStack(spacing: 4) {
                    Text(title)
                        .font(.labelLarge)
                        .lineSpacing(28 - 18) // line-height 28px - font-size 18px = 10px
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.bodyXS)
                        .lineSpacing(16 - 13) // line-height 16px - font-size 13px = 3px
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}

