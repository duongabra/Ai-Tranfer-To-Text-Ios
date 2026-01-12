//
//  PrimaryButton.swift
//  Chat-Ai
//
//  Primary Button Component theo Design System
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .padding(2)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .textWhite))
                } else {
                    Text(title)
                        .font(.labelMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .padding(.leading, icon != nil ? 10 : 20)
            .background(Color.primaryOrange)
            .foregroundColor(.textWhite)
            .cornerRadius(BorderRadius.button)
        }
        .disabled(isLoading)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Sign in with Apple", icon: "apple.logo", action: {})
        PrimaryButton(title: "Sign in with Apple", icon: "apple.logo", action: {}, isLoading: true)
    }
    .padding()
}

