//
//  LinkIcon.swift
//  Chat-Ai
//
//  Link icon từ SVG (Icon (1).svg) - Chain link với glow effect
//

import SwiftUI

struct LinkIcon: View {
    var size: CGFloat = 48
    
    var body: some View {
        ZStack {
            // Background circle (#FF920A)
            Circle()
                .fill(Color.accentOrange)
                .frame(width: size, height: size)
            
            // Chain link icon với glow effect (#FAFAFA)
            // Từ SVG: 2 chain links nối với nhau
            ZStack {
                // Glow effect (shadow layer)
                Image(systemName: "link")
                    .font(.custom("Overused Grotesk", size: size * 0.4))
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.4))
                    .blur(radius: 1.5)
                
                // Main link icon
                Image(systemName: "link")
                    .font(.custom("Overused Grotesk", size: size * 0.4))
                    .fontWeight(.semibold)
                    .foregroundColor(.textWhite)
            }
        }
    }
}

#Preview {
    LinkIcon()
}

