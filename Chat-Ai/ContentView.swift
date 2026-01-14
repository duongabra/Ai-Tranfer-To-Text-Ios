//
//  ContentView.swift
//  Chat-Ai
//
//  Main content view - hiển thị HomeView
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        // Hiển thị màn hình Home
        HomeView()
            .task {
                
                // Đợi một chút để đảm bảo checkCurrentUser() đã chạy
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 giây
                
                // Load đầy đủ thông tin user từ DB ngay khi app khởi động
                if let userId = authViewModel.currentUser?.id {
                    await authViewModel.loadUserInfoFromDB(userId: userId)
                } else {
                }
                
                // Load conversations ngay khi app khởi động
                await ConversationListViewModel.shared.loadConversations()
            }
    }
}

#Preview {
    ContentView()
}
