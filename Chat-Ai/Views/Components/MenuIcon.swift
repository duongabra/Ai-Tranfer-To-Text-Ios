//
//  MenuIcon.swift
//  Chat-Ai
//
//  Menu icon (3 gạch ngang) từ SVG
//

import SwiftUI

struct MenuIcon: View {
    var size: CGFloat = 15
    
    var body: some View {
        // 3 horizontal lines với spacing chính xác từ SVG
        // SVG: width="15" height="14", 3 paths với y positions khác nhau
        VStack(spacing: 0) {
            // Line 1 (top) - y position từ SVG
            Rectangle()
                .fill(Color.textPrimary)
                .frame(width: size, height: 1.33)
            
            // Line 2 (middle) - spacing 5.83 từ line 1
            Rectangle()
                .fill(Color.textPrimary)
                .frame(width: size, height: 1.33)
                .padding(.top, 5.83)
            
            // Line 3 (bottom) - spacing 5.83 từ line 2
            Rectangle()
                .fill(Color.textPrimary)
                .frame(width: size, height: 1.33)
                .padding(.top, 5.83)
        }
        .frame(width: size, height: 14)
    }
}

#Preview {
    MenuIcon()
}

