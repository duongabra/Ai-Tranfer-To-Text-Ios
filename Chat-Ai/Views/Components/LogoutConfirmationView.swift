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
            // Background blur overlay
            Color.white.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal content - bottom sheet
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Content
                VStack(spacing: 12) {
                    Text("Do you want to log out of \(formatEmail(authViewModel.currentUser?.email ?? "")) on Vidsum?")
                        .font(.custom("Overused Grotesk", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#020202"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(0)
                        .padding(.top, 8)
                    
                    // Button group
                    HStack(spacing: 16) {
                        // Cancel button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.custom("Overused Grotesk", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "#020202"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "E4E4E4"), lineWidth: 1)
                                )
                        }
                        
                        // Yes button
                        Button(action: {
                            handleLogout()
                        }) {
                            Text("Yes")
                                .font(.custom("Overused Grotesk", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "#FAFAFA"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "#FF3D33"))
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Helper Functions
    
    private func formatEmail(_ email: String) -> String {
        if email.count > 20 {
            return String(email.prefix(20)) + "..."
        }
        return email
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
