//
//  SettingsView.swift
//  Chat-Ai
//
//  Settings popup trong drawer
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background blur overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Modal content - bottom sheet
            VStack(spacing: 0) {
                // Header
                HStack {
                    // Empty space for centering
                    Spacer()
                        .frame(width: 40)
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.custom("Overused Grotesk", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // User Profile Section
                        VStack(spacing: 8) {
                                // Avatar
                                AsyncImage(url: URL(string: authViewModel.currentUser?.avatarURL ?? "")) { phase in
                                    switch phase {
                                    case .empty, .failure:
                                        Circle()
                                            .fill(Color(hex: "D9D9D9"))
                                            .frame(width: 64, height: 64)
                                            .overlay(
                                                Text(formatUserName(authViewModel.currentUser?.displayName ?? authViewModel.currentUser?.email ?? "U").prefix(1).uppercased())
                                                    .font(.custom("Overused Grotesk", size: 24))
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.textPrimary)
                                            )
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 64, height: 64)
                                            .clipShape(Circle())
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                
                                // Name and Email
                                VStack(spacing: 4) {
                                    Text(authViewModel.currentUser?.displayName ?? "User")
                                        .font(.custom("Overused Grotesk", size: 16))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text(formatEmail(authViewModel.currentUser?.email ?? ""))
                                        .font(.custom("Overused Grotesk", size: 14))
                                        .fontWeight(.regular)
                                        .foregroundColor(.textTertiary)
                                }
                                
                                // Edit Profile Button
                                Button(action: {
                                    // TODO: Navigate to edit profile
                                }) {
                                    Text("Edit Profile")
                                        .font(.custom("Overused Grotesk", size: 13))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.borderGray, lineWidth: 1)
                                        )
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        
                        // Upgrade to Pro Section
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
                                        .font(.custom("Overused Grotesk", size: 16))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text("Pro unlocks higher limits")
                                        .font(.custom("Overused Grotesk", size: 12))
                                        .fontWeight(.regular)
                                        .foregroundColor(.textTertiary)
                                }
                                
                                Spacer()
                                
                                // Upgrade Button
                                Button(action: {
                                    dismiss()
                                    navigationCoordinator.navigationPath.append(PaywallDestination())
                                }) {
                                    Text("Upgrade")
                                        .font(.custom("Overused Grotesk", size: 14))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textWhite)
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
                                iconImage: "Group (2)",
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
                                iconImage: "Group (3)",
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
                                Task {
                                    do {
                                        try await AuthService.shared.signOut()
                                        authViewModel.currentUser = nil
                                        dismiss()
                                    } catch {
                                        print("❌ Sign out error: \(error)")
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image("align_arrow_right_line")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "CC0A00"))
                                    
                                    Text("Log Out")
                                        .font(.custom("Overused Grotesk", size: 14))
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "CC0A00"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
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
            .frame(maxHeight: UIScreen.main.bounds.height * 0.9)
            .background(Color.white)
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(edges: .bottom)
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
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.custom("Overused Grotesk", size: 14))
                        .fontWeight(.regular)
                        .foregroundColor(.textSecondary)
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

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(NavigationCoordinator())
}

