//
//  DeleteAccountConfirmationView.swift
//  Chat-Ai
//
//  Confirmation view để xóa account
//

import SwiftUI

struct DeleteAccountConfirmationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @Binding var isDeleting: Bool
    var onConfirm: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background blur overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    if !isDeleting {
                        isPresented = false
                    }
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Delete Account")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: {
                        if !isDeleting {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary)
                            .frame(width: 28, height: 28)
                    }
                    .disabled(isDeleting)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                // Content
                VStack(spacing: 16) {
                    Text("Are you sure you want to delete your account?")
                        .font(Font.custom("Overused Grotesk", size: 14).weight(.regular))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    Text("This action cannot be undone. All your data, conversations, and files will be permanently deleted.")
                        .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    // Buttons
                    HStack(spacing: 12) {
                        // Cancel button
                        Button(action: {
                            if !isDeleting {
                                isPresented = false
                            }
                        }) {
                            Text("Cancel")
                                .font(Font.custom("Overused Grotesk", size: 16).weight(.semibold))
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "E4E4E4"), lineWidth: 1)
                                )
                                .cornerRadius(16)
                        }
                        .disabled(isDeleting)
                        
                        // Delete button
                        Button(action: {
                            onConfirm()
                        }) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(16)
                            } else {
                                Text("Delete")
                                    .font(Font.custom("Overused Grotesk", size: 16).weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(isDeleting)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.bottom, 32)
            }
            .background(Color.white)
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    DeleteAccountConfirmationView(
        isPresented: .constant(true),
        isDeleting: .constant(false),
        onConfirm: {}
    )
    .environmentObject(AuthViewModel())
}
