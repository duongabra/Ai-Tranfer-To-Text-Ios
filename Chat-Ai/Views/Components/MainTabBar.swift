//
//  MainTabBar.swift
//  Chat-Ai
//
//  Bottom tab bar (Figma 55496-2094): pill shape, frosted glass, 3 items. Center = 60px black circle, 12px padding, white lipstick, pink glow.
//

import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: Int

    private let barHeight: CGFloat = 48
    private let horizontalPadding: CGFloat = 12
    private let itemSpacing: CGFloat = 8
    private let centerButtonSize: CGFloat = 60
    private let sideButtonSize: CGFloat = 48

    var body: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: itemSpacing) {
                sideTabItem(iconName: "tab_home", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }

                Color.clear.frame(width: centerButtonSize, height: sideButtonSize)

                sideTabItem(iconName: "tab_profile", isSelected: selectedTab == 2) {
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
            centerButton
        }
        .frame(height: centerButtonSize)
    }

    // MARK: - Center Button (luôn có black circle + pink glow)

    private var centerButton: some View {
        Button(action: { selectedTab = 1 }) {
            ZStack {
                Circle()
                    .fill(Color(hex: "030712"))
                    .frame(width: centerButtonSize, height: centerButtonSize)
                    .shadow(color: Color(hex: "F57EB6").opacity(0.2), radius: 16, x: 0, y: 0)

                Image("tab_lipstick")
                    .renderingMode(.template)
                    .foregroundColor(Color(hex: "F9FAFB"))
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Side Tab Items (Home, Profile)

    private func sideTabItem(iconName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(iconName)
                .renderingMode(.template)
                .foregroundColor(isSelected ? .black : Color.black.opacity(0.4))
                .frame(width: 20, height: 19)
                .frame(width: sideButtonSize, height: sideButtonSize)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
