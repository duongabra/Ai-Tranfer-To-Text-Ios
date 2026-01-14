//
//  SettingsView.swift
//  Chat-Ai
//
//  Settings popup trong drawer 
//

import SwiftUI
import UIKit
import Foundation

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @Binding var isPresented: Bool
    
    @State private var showingEditProfile = false
    @State private var showingLogoutConfirmation = false
    @State private var hasActiveSubscription = false
    
    init(isPresented: Binding<Bool> = .constant(true)) {
        _isPresented = isPresented
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundOverlay
            modalContent
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            await checkSubscriptionStatus()
        }
        .overlay(alignment: .bottom) {
            if showingEditProfile {
                EditProfileView(isPresented: $showingEditProfile)
                    .environmentObject(authViewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(1000)
            }
        }
        .overlay(alignment: .bottom) {
            if showingLogoutConfirmation {
                LogoutConfirmationView(isPresented: $showingLogoutConfirmation)
                    .environmentObject(authViewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(2000)
            }
        }
    }
    
    // MARK: - Background Overlay
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    isPresented = false
                }
            }
    }
    
    // MARK: - Modal Content
    
    private var modalContent: some View {
        VStack(spacing: 0) {
            headerView
            contentScrollView
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.9)
        .background(Color.white)
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Spacer()
                .frame(width: 40)
            
            Spacer()
            
            Text("Settings")
                .font(.custom("Overused Grotesk", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#020202"))
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .lineLimit(1)
                .textCase(nil)
                .environment(\.font, .custom("Overused Grotesk", size: 16))
                .font(.system(size: 16, weight: .semibold))
                .fontDesign(.default)
                .monospacedDigit()
                .frame(height: 24, alignment: .center)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Content Scroll View
    
    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                        // User Profile Section
                        VStack(spacing: 8) {
                                // Avatar
                                AvatarView(avatarURL: authViewModel.currentUser?.avatarURL, size: 64)
                                
                                // Name and Email
                                VStack(spacing: 4) {
                                    UserDisplayNameText()
                                        .environmentObject(authViewModel)
                                        .font(.custom("Overused Grotesk", size: 16))
                                        .fontWeight(.semibold) // 600
                                        .foregroundColor(Color(hex: "#020202")) // matches var(--text-neutral-text-neutral-primary, #020202)
                                        .lineLimit(1)
                                        .truncationMode(.tail) // for text-overflow: ellipsis
                                        .multilineTextAlignment(.center) // text-align: center
                                        .monospacedDigit() // for tabular-nums, lining-nums is default in SwiftUI
                                        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .center) // line-height: 24px; overflow hidden via lineLimit
                                    
                                    Text(formatEmail(authViewModel.currentUser?.email ?? ""))
                                        .font(.custom("Overused Grotesk", size: 14))
                                        .fontWeight(.regular)
                                        .foregroundColor(Color.black.opacity(0.6)) // rgba(0,0,0,0.60)
                                        .multilineTextAlignment(.center)
                                        .monospacedDigit() // tabular-nums, lining-nums is default in SwiftUI
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20, alignment: .center)
                                }
                                
                                // Edit Profile Button
                                Button(action: {
                                    showingEditProfile = true
                                }) {
                                    Text("Edit Profile")
                                        .font(.custom("Overused Grotesk", size: 13))
                                        .fontWeight(.semibold) // 600 weight
                                        .foregroundColor(Color(hex: "#020202"))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.borderGray, lineWidth: 1)
                                        )
                                        .lineSpacing(3) // 16px line height - 13px font size = 3px
                                        .monospacedDigit() // ensures tabular nums
                                        .fontDesign(.monospaced) // for slashed zero/lining if available, fallback
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        
                        // Upgrade to Pro Section - Chỉ hiển thị nếu chưa có subscription
                        if !hasActiveSubscription {
                            HStack(spacing: 8) {
                                    // Icon
                                    Image("icon-trailing")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .padding(2)
                                    
                                    // Text
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upgrade to Pro")
                                            .font(.custom("Overused Grotesk", size: 16).weight(.semibold)   )
                                            .foregroundColor(Color(hex: "#020202")) // var(--text-neutral-text-neutral-primary, #020202)
                                            .lineLimit(1)
                                            .truncationMode(.tail) // text-overflow: ellipsis
                                            .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .leading) // line-height: 24px; overflow hidden via lineLimit
                                        
                                        Text("Pro unlocks higher limits")
                                            .font(.custom("Overused Grotesk", size: 12).weight(.regular))
                                            .foregroundColor(Color.black.opacity(0.6))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, minHeight: 12, maxHeight: 12, alignment: .leading)
                                    }
                                    
                                    Spacer()
                                    
                                    // Upgrade Button
                                    Button(action: {
                                        handleUpgrade()
                                    }) {
                                        Text("Upgrade")
                                            .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                                            .foregroundColor(Color(hex: "#FAFAFA")) // var(--text-neutral-text-neutral-inverse-primary, #FAFAFA)
                                            .frame(minHeight: 20, maxHeight: 20, alignment: .center) // line-height: 20px
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.primaryOrange)
                                            .cornerRadius(16)
                                    }
                            }
                            .padding(16)
                            .background(Color.primaryOrange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primaryOrange.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        
                        // Settings Options
                        VStack(spacing: 0) {
                            // Language
                            SettingsRow(
                                iconImage: "world_2_line",
                                title: "Language",
                                value: "English",
                                showArrow: true,
                                action: {
                                    // TODO: Show language picker
                                }
                            )
                            
                            // Divider
                            Rectangle()
                                .fill(Color(hex: "F4F4F4"))
                                .frame(height: 1)
                                .padding(.leading, 60)
                            
                            // Terms of Services
                            SettingsRow(
                                iconImage: "group_2",
                                title: "Terms of Services",
                                showArrow: true,
                                action: {
                                    // TODO: Open Terms of Services
                                }
                            )
                            
                            // Divider
                            Rectangle()
                                .fill(Color(hex: "F4F4F4"))
                                .frame(height: 1)
                                .padding(.leading, 60)
                            
                            // Privacy
                            SettingsRow(
                                iconImage: "group_3",
                                title: "Privacy",
                                showArrow: true,
                                action: {
                                    // TODO: Open Privacy Policy
                                }
                            )
                        }
                        .padding(16)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "F4F4F4"), lineWidth: 1)
                        )
                        .cornerRadius(16)
                        
                        // Log Out Button
                        Button(action: {
                            showingLogoutConfirmation = true
                        }) {
                                HStack(spacing: 8) {
                                    Image("align_arrow_right_line")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "CC0A00"))
                                    
                                    Text("Log Out")
                                        .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                                        .foregroundColor(Color(hex: "#CC0A00"))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.leading, 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "F4F4F4"), lineWidth: 1)
                                )
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
    }
    
    // MARK: - Check Subscription Status
    
    private func checkSubscriptionStatus() async {
        // TẠM THỜI: Check subscription từ StoreKit 2
        let currentProductId = await StoreKitService.shared.getCurrentSubscriptionProductId()
        hasActiveSubscription = (currentProductId != nil)
    }
    
    // MARK: - Upgrade Button Action
    
    private func handleUpgrade() {
        dismiss()
        navigationCoordinator.navigationPath.append(PaywallDestination())
    }
    
    private func formatUserName(_ name: String) -> String {
        if name.count > 10 {
            return String(name.prefix(10)) + "..."
        }
        return name
    }
    
    private func formatEmail(_ email: String) -> String {
        if email.count > 20 {
            return String(email.prefix(20)) + "..."
        }
        return email
    }
    
    
}

// MARK: - Settings Row

struct SettingsRow: View {
    var iconImage: String? = nil
    var iconSystemName: String? = nil
    let title: String
    var value: String? = nil
    var showArrow: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconImage = iconImage {
                    Image(iconImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.textPrimary)
                } else if let iconSystemName = iconSystemName {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 20))
                        .foregroundColor(.textPrimary)
                        .frame(width: 20, height: 20)
                }
                
                Text(title)
                    .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                    .foregroundColor(Color(hex: "#020202")) // var(--text-neutral-text-neutral-primary, #020202)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.custom("Overused Grotesk", size: 14))
                        .foregroundColor(Color(hex: "#303030")) // var(--text-neutral-text-neutral-secondary, #303030)
                        .frame(maxWidth: .infinity, alignment: .trailing) // text-align: right
                }
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.textPrimary)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

// MARK: - User Display Name View

struct UserDisplayNameText: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var displayName: String = "User"
    
    var body: some View {
        Text(displayName)
            .onAppear {
                loadDisplayName()
            }
            .onChange(of: authViewModel.currentUser?.id) { _ in
                loadDisplayName()
            }
            .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { _ in
                // Refresh khi có notification profile đã được update
                loadDisplayName()
            }
    }
    
    private func loadDisplayName() {
        Task {
            let name = await authViewModel.getUserDisplayName()
            await MainActor.run {
                displayName = name
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AuthViewModel())
        .environmentObject(NavigationCoordinator())
}



#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AuthViewModel())
        .environmentObject(NavigationCoordinator())
}

