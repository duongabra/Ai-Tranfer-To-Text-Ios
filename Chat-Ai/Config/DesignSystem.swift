//
//  DesignSystem.swift
//  Chat-Ai
//
//  Design System - Colors, Fonts, Spacing theo Figma
//

import SwiftUI

// MARK: - Colors
extension Color {
    // Primary Colors
    static let primaryOrange = Color(hex: "D87757")
    static let backgroundCream = Color(hex: "FFF9F2")
    static let accentOrange = Color(hex: "FF920A")
    
    // Text Colors
    static let textPrimary = Color(hex: "020202")
    static let textSecondary = Color(hex: "303030")
    static let textTertiary = Color(hex: "717171")
    
    // Border & Stroke
    static let borderGray = Color(hex: "E4E4E4")
    
    // White
    static let textWhite = Color(hex: "FAFAFA")
}

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
extension Font {
    // Heading Large - 28px, weight 600, line-height 36px (128.571%)
    static let headingLarge = Font.system(size: 28, weight: .semibold)
    
    // Body Medium - 14px, weight 400, line-height 19.6px (140%)
    static let bodyMedium = Font.system(size: 14, weight: .regular)
    
    // Label Large - 18px, weight 600, line-height 28px (155.556%)
    static let labelLarge = Font.system(size: 18, weight: .semibold)
    
    // Label Medium (Button) - 16px, weight 600
    static let labelMedium = Font.system(size: 16, weight: .semibold)
    
    // Body XS - 13px, weight 400, line-height 16px (123.077%)
    static let bodyXS = Font.system(size: 13, weight: .regular)
}

// MARK: - Spacing
struct Spacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

// MARK: - Border Radius
struct BorderRadius {
    static let button: CGFloat = 16
    static let card: CGFloat = 12
}

