//
//  LogoutConfirmationView.swift
//  Chat-Ai
//
//  Logout confirmation popup
//

import SwiftUI
import UIKit

struct LogoutConfirmationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Mask: rgba(255,255,255,0.3) + blur 8px (Figma)
            Color.white.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture { isPresented = false }
            
            // Modal: white, top corners 20px, padding 20 20 32, gap 16 (Figma 55499-2642)
            VStack(alignment: .leading, spacing: 16) {
                // Header: title + close (space-between)
                HStack {
                    Text("Do you want to logout?")
                        .font(.custom("Overused Grotesk", size: 18))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "101828"))
                    Spacer(minLength: 0)
                    Button(action: { isPresented = false }) {
                        Image("logout_modal_close_icon")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(Color(hex: "4A5565"))
                            .padding(8)
                    }
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(Circle())
                    .contentShape(Rectangle())
                }
                
                // Body: description (body-sm 14px #364153)
                Text("You'll need to sign in again to access your saved swatches and history.")
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "364153"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Buttons: VStack gap 12 (Figma)
                VStack(spacing: 12) {
                    // Logout: danger filled #E23939, icon exit leading, pill
                    Button(action: { handleLogout() }) {
                        HStack(spacing: 8) {
                            Image("logout_exit_icon")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .foregroundColor(Color(hex: "F9FAFB"))
                            Text("Logout")
                                .font(.custom("Overused Grotesk", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "F9FAFB"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .padding(.leading, 10)
                        .background(Color(hex: "E23939"))
                        .cornerRadius(9999)
                    }
                    
                    // Cancel: outline 1px #101828, text #101828
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .font(.custom("Overused Grotesk", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: "101828"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 9999)
                            .stroke(Color(hex: "101828"), lineWidth: 1)
                    )
                    .cornerRadius(9999)
                }
            }
            .padding(20)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func handleLogout() {
        Task {
            do {
                try await AuthService.shared.signOut()
                authViewModel.currentUser = nil
                isPresented = false
                dismiss()
            } catch {
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LogoutConfirmationView(isPresented: .constant(true))
        .environmentObject(AuthViewModel())
}
