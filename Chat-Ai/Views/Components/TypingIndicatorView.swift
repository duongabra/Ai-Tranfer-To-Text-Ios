//
//  TypingIndicatorView.swift
//  Chat-Ai
//
//  Typing indicator với animation (dấu ... nhảy)
//

import SwiftUI

struct TypingIndicatorView: View {
    
    @State private var animatingDot1 = false
    @State private var animatingDot2 = false
    @State private var animatingDot3 = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Avatar AI (icon)
            Image(systemName: "cpu")
                .font(.custom("Overused Grotesk", size: 22))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Typing bubble
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot1 ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(0),
                        value: animatingDot1
                    )
                
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot2 ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(0.2),
                        value: animatingDot2
                    )
                
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot3 ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(0.4),
                        value: animatingDot3
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animatingDot1 = true
            animatingDot2 = true
            animatingDot3 = true
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}

