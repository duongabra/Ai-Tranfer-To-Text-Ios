//
//  Chat_AiApp.swift
//  Chat-Ai
//
//  App entry point với authentication
//

import SwiftUI

@main
struct Chat_AiApp: App {
    
    // StateObject: Tạo và giữ AuthViewModel cho toàn app
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Configure RevenueCat khi app launch
        Task {
            await RevenueCatService.shared.configure()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Kiểm tra user đã đăng nhập chưa
            if authViewModel.currentUser != nil {
                // Đã đăng nhập → Hiển thị app chính
            ContentView()
                    .environmentObject(authViewModel)
                    .environment(\.font, .appDefault)
                    .foregroundColor(.textPrimary)
                    .task {
                        // ✅ Kiểm tra và refresh token khi app khởi động
                        await AuthService.shared.checkAndRefreshTokenIfNeeded()
                    }
            } else {
                // Chưa đăng nhập → Hiển thị màn hình login
                LoginView()
                    .environmentObject(authViewModel)
                    .environment(\.font, .appDefault)
                    .foregroundColor(.textPrimary)
            }
        }
    }
}
