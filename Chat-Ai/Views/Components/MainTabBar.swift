//
//  MainTabBar.swift
//  Chat-Ai
//
//  Bottom tab bar (Figma 55496-2094): pill shape, frosted glass, 3 items. Center = 60px black circle, 12px padding, white lipstick, pink glow.
//

import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: Int

    private let barHeight: CGFloat = 60
    private let horizontalPadding: CGFloat = 12
    private let itemSpacing: CGFloat = 8
    private let centerButtonSize: CGFloat = 60
    private let centerInnerPadding: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: itemSpacing) {
            tabItem(index: 0, iconName: "tab_home", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            tabItem(index: 1, iconName: "tab_lipstick", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            tabItem(index: 2, iconName: "tab_profile", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: barHeight)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 999)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.white.opacity(0.2))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
    }

    @ViewBuilder
    private func tabItem(index: Int, iconName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if index == 1 && isSelected {
                    Circle()
                        .fill(Color(hex: "030712"))
                        .frame(width: centerButtonSize, height: centerButtonSize)
                        .shadow(color: Color(hex: "F57EB6").opacity(0.25), radius: 16, x: 0, y: 0)
                    Image(iconName)
                        .renderingMode(.original)
                        .frame(width: 24, height: 24)
                        .padding(centerInnerPadding) // 12pt space from circle edge to icon
                } else {
                    Image(iconName)
                        .renderingMode(.template)
                        .foregroundColor(iconName == "tab_profile" ? Color.black.opacity(0.4) : .black)
                        .frame(width: index == 1 ? 24 : 20, height: index == 1 ? 24 : 19)
                }
            }
            .frame(width: index == 1 ? centerButtonSize : 48, height: index == 1 ? centerButtonSize : 48)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
