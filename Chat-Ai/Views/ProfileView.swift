//
//  ProfileView.swift
//  Chat-Ai
//
//  Màn Profile: avatar, tên, email, menu (Language, Manage Subscription, Term, Privacy), Logout.
//  Bấm avatar ở Home → vào đây. Manage Subscription → Paywall.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var subscriptionViewModel = SubscriptionViewModel.shared
    @State private var showingLogoutConfirmation = false
    /// When true (e.g. shown as tab), hide the close button.
    var isEmbeddedInTab: Bool = false

    private var displayName: String {
        guard let user = authViewModel.currentUser else { return "Beauty" }
        let first = (user.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let last = (user.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { return last }
        if !first.isEmpty { return first }
        return "Beauty"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    profileHeader
                    menuCard
                    logoutCard
                }
                .padding(.top, 56)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            if !isEmbeddedInTab { closeButton }
        }
        .navigationBarHidden(true)
        .preference(key: HideTabBarKey.self, value: true)
        .onAppear {
            Task { await subscriptionViewModel.loadSubscriptionStatus(forceRefresh: true) }
        }
        .overlay {
            if showingLogoutConfirmation {
                LogoutConfirmationView(isPresented: $showingLogoutConfirmation)
            }
        }
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "101828"))
                .frame(width: 32, height: 32)
                .background(Color(hex: "F9FAFB"))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 16)
        .padding(.trailing, 20)
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                profileAvatar
                    .frame(width: 80, height: 80)
                if subscriptionViewModel.hasPremiumAccess() {
                    HStack(spacing: 3) {
                        Image("pro_badge_crown")
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 10, height: 8)
                        Text("PRO")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(EdgeInsets(top: 4, leading: 8, bottom: 2, trailing: 8))
                    .background(Color.black)
                    .clipShape(Capsule())
                    .offset(y: 6)
                } else {
                    Text("Free")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 2, trailing: 8))
                        .background(Color.black)
                        .clipShape(Capsule())
                        .offset(y: 6)
                }
            }
            .frame(height: 100)

            Text(displayName)
                .font(.custom("Overused Grotesk", size: 24).weight(.bold))
                .foregroundColor(Color(hex: "101828"))

            if let email = authViewModel.currentUser?.email {
                Text(email.count > 30 ? String(email.prefix(30)) + "..." : email)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var profileAvatar: some View {
        Group {
            if let urlString = authViewModel.currentUser?.avatarURL,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(width: 80, height: 80)
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(hex: "6A7282"))
                    @unknown default:
                        Color(hex: "E4E4E4")
                    }
                }
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: "E5E7EB"), lineWidth: 1))
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "6A7282"))
            }
        }
        .frame(width: 80, height: 80)
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            profileRowLink(icon: "profile_language", label: "Language", trailing: "English", destination: nil)
            Divider().background(Color(hex: "E5E7EB")).padding(.horizontal, 16)
            profileRowLink(icon: "profile_manage_sub", label: "Manage Subscription", trailing: nil, destination: AnyView(PaywallView()))
            Divider().background(Color(hex: "E5E7EB")).padding(.horizontal, 16)
            profileRowLink(icon: "profile_term", label: "Term of Services", trailing: nil, destination: nil)
            Divider().background(Color(hex: "E5E7EB")).padding(.horizontal, 16)
            profileRowLink(icon: "profile_privacy", label: "Privacy", trailing: nil, destination: nil)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        )
    }

    private func profileRowLink(icon: String, label: String, trailing: String?, destination: AnyView?) -> some View {
        Group {
            if let dest = destination {
                NavigationLink(destination: dest) {
                    profileMenuItemContent(icon: icon, label: label, trailingText: trailing)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {}) {
                    profileMenuItemContent(icon: icon, label: label, trailingText: trailing)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func profileMenuItemContent(icon: String, label: String, trailingText: String?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(Color(hex: "030712"))
                .frame(width: 20, height: 20)
            Text(label)
                .font(.custom("Overused Grotesk", size: 16).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
            Spacer()
            if let t = trailingText {
                Text(t)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "9CA3AF"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var logoutCard: some View {
        Button(action: { showingLogoutConfirmation = true }) {
            HStack(alignment: .center, spacing: 12) {
                Image("profile_logout")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(Color(hex: "030712"))
                    .frame(width: 20, height: 20)
                Text("Logout")
                    .font(.custom("Overused Grotesk", size: 16).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}
