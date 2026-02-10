//
//  ContentView.swift
//  Chat-Ai
//
//  Main content: 3 tabs (Home, Swatch Upload, My Swatches) + bottom tab bar (Figma 55496-2094).
//

import SwiftUI

/// Preference: con (SwatchUploadView) báo đang hiển thị → ẩn tab bar. Dùng chung với SwatchUploadView.
struct HideTabBarKey: PreferenceKey {
    static var defaultValue: Bool { false }
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab: Int = 0
    @State private var hideTabBar: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedTab == 0 {
                    NavigationView {
                        HomeView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                } else if selectedTab == 1 {
                    NavigationView {
                        SwatchUploadView(onClose: { selectedTab = 0 })
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                } else {
                    MySwatchesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(HideTabBarKey.self) { hideTabBar = $0 }

            if !hideTabBar {
                MainTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(.keyboard)
        .task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            if let userId = authViewModel.currentUser?.id {
                await authViewModel.loadUserInfoFromDB(userId: userId)
            }
        }
    }
}

#Preview {
    ContentView()
}
