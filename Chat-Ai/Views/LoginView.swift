//
//  LoginView.swift
//  Chat-Ai
//
//  Màn hình đăng nhập với Google
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            
            Spacer()
            
            // MARK: - Logo & Title
            
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // Title
                Text("Chat AI")
                    .font(.system(size: 42, weight: .bold))
                
                // Subtitle
                Text("Chat với AI đơn giản & nhanh")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // MARK: - Sign In Button
            
            VStack(spacing: 16) {
                
                // Google Sign In Button
                Button(action: {
                    Task {
                        await authViewModel.signInWithGoogle()
                    }
                }) {
                    HStack(spacing: 12) {
                        // Google Icon (sử dụng SF Symbol tạm thời)
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(authViewModel.isLoading)
                
                // Loading indicator
                if authViewModel.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }
                
                // Error message
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

