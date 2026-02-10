//
//  LoginView.swift
//  Chat-Ai
//
//  Màn hình đăng nhập theo Figma Design
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    // Figma colors
    private let titleColor = Color(red: 16/255, green: 24/255, blue: 40/255)   // #101828
    private let bodyColor = Color(red: 106/255, green: 114/255, blue: 130/255) // #6A7282
    private let appleBgColor = Color(red: 3/255, green: 7/255, blue: 18/255)   // #030712
    private let appleTextColor = Color(red: 249/255, green: 250/255, blue: 251/255) // #F9FAFB
    private let googleStrokeColor = Color(red: 16/255, green: 24/255, blue: 40/255) // #101828

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero image from top edge, fill sát không khoảng trắng
                Image("LoginHero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 328)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .clipped()

                // Main panel
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add the lipstick you want to try")
                            .font(.custom("Overused Grotesk", size: 24).weight(.semibold))
                            .foregroundColor(titleColor)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Upload 2–3 photos so we can detect the brand, product line, and shade accurately.")
                            .font(.custom("Overused Grotesk", size: 16).weight(.regular))
                            .foregroundColor(bodyColor)
                            .multilineTextAlignment(.center)
                            .lineSpacing(24 - 16)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    VStack(spacing: 12) {
                        // Sign in with Apple (black background)
                        Button {
                            Task { await authViewModel.signInWithApple() }
                        } label: {
                            HStack(spacing: 8) {
                                if authViewModel.isLoadingApple {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: appleTextColor))
                                } else {
                                    Image(systemName: "apple.logo")
                                        .font(.custom("Overused Grotesk", size: 20))
                                    Text("Sign in with Apple")
                                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(appleBgColor)
                            .foregroundColor(appleTextColor)
                            .cornerRadius(BorderRadius.button)
                        }
                        .disabled(authViewModel.isLoadingApple)

                        // Sign in with Google (white + stroke)
                        Button {
                            Task { await authViewModel.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 8) {
                                if authViewModel.isLoadingGoogle {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: titleColor))
                                } else {
                                    GoogleIcon(size: 20)
                                    Text("Sign in with Google")
                                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.white)
                            .foregroundColor(titleColor)
                            .cornerRadius(BorderRadius.button)
                            .overlay(
                                RoundedRectangle(cornerRadius: BorderRadius.button)
                                    .stroke(googleStrokeColor, lineWidth: 1)
                            )
                        }
                        .disabled(authViewModel.isLoadingGoogle)

                        if let errorMessage = authViewModel.errorMessage {
                            Text(errorMessage)
                                .font(.custom("Overused Grotesk", size: 12))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
