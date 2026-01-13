//
//  LoginView.swift
//  Chat-Ai
//
//  Màn hình đăng nhập theo Figma Design
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Background color
            Color.backgroundCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Content
                VStack(spacing: 16) {
                    
                    // Hero Illustration
                    Image("login_hero")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 390, height: 390)
                    
                    // Text Section
                    VStack(spacing: 12) {
                        Text("Analyze your video / audio")
                            .font(.custom("Overused Grotesk", size: 28))
                            .fontWeight(.semibold)
                            .lineSpacing(36 - 28)
                            .fontDesign(.default) // Mimic font-family-sans
                            .foregroundColor(Color(red: 2/255, green: 2/255, blue: 2/255))
                            .multilineTextAlignment(.center)
                            .environment(\.font, .system(.body, design: .default).lowercaseSmallCaps().monospacedDigit())
                        
                        Text("AI summaries and insights from any content")
                            .font(.custom("Overused Grotesk", size: 16))
                            .fontWeight(.regular)
                            .foregroundColor(Color(red: 48/255, green: 48/255, blue: 48/255))
                            .multilineTextAlignment(.center)
                            .lineSpacing(24 - 16)
                            .fontDesign(.default)
                            .environment(\.font, .system(.body, design: .default).monospacedDigit())
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // MARK: - Buttons
                VStack(spacing: 16) {
                    
                    // Sign in with Apple Button
                    PrimaryButton(
                        title: "Sign in with Apple",
                        icon: "apple.logo",
                        action: {
                            Task {
                                await authViewModel.signInWithApple()
                            }
                        },
                        isLoading: authViewModel.isLoading
                    )
                    
                    // Sign in with Google Button
                    SecondaryButton(
                        title: "Sign in with Google",
                        icon: .google,
                        action: {
                            Task {
                                await authViewModel.signInWithGoogle()
                            }
                        },
                        isLoading: authViewModel.isLoading
                    )
                    
                    // Error message
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.custom("Overused Grotesk", size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

