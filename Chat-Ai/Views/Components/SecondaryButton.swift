//
//  SecondaryButton.swift
//  Chat-Ai
//
//  Secondary Button Component theo Design System
//

import SwiftUI

enum ButtonIcon {
    case system(String)
    case google
    
    @ViewBuilder
    func view(size: CGFloat = 20) -> some View {
        switch self {
        case .system(let name):
            Image(systemName: name)
                .font(.custom("Overused Grotesk", size: size))
                .padding(2)
        case .google:
            GoogleIcon(size: size)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: ButtonIcon?
    let action: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    icon.view(size: 20)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .textPrimary))
                } else {
                    Text(title)
                        .font(.labelMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .padding(.leading, icon != nil ? 10 : 20)
            .background(Color.white)
            .foregroundColor(.textPrimary)
            .cornerRadius(BorderRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.button)
                    .stroke(Color.borderGray, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: "Sign in with Google", icon: .google, action: {})
        SecondaryButton(title: "Sign in with Google", icon: .google, action: {}, isLoading: true)
    }
    .padding()
    .background(Color.backgroundCream)
}

