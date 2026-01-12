//
//  UploadIcon.swift
//  Chat-Ai
//
//  Upload icon từ SVG (Icon.svg) - Cloud với arrow up
//

import SwiftUI

struct UploadIcon: View {
    var size: CGFloat = 48
    
    var body: some View {
        ZStack {
            // Background circle (#D87757)
            Circle()
                .fill(Color.primaryOrange)
                .frame(width: size, height: size)
            
            // Cloud with arrow up icon (#FAFAFA)
            // Từ SVG: cloud ở trên, arrow ở dưới
            VStack(spacing: size * 0.15) {
                // Cloud icon
                Image(systemName: "cloud.fill")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(.textWhite)
                
                // Arrow up
                Image(systemName: "arrow.up")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundColor(.textWhite)
            }
        }
    }
}

#Preview {
    UploadIcon()
}

