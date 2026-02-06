//
//  ContentView.swift
//  Chat-Ai
//
//  Main content view - sau đăng nhập vào Home, Home có nút Pro → Paywall
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            HomeView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
