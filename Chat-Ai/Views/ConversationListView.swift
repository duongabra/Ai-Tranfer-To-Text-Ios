//
//  ConversationListView.swift
//  Chat-Ai
//
//  Màn hình hiển thị danh sách các cuộc hội thoại
//

import SwiftUI

struct ConversationListView: View {
    
    // StateObject: tạo và giữ ViewModel trong suốt lifecycle của View
    @StateObject private var viewModel = ConversationListViewModel()
    
    // EnvironmentObject: Lấy AuthViewModel từ parent
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // State để hiển thị/ẩn sheet tạo conversation mới
    @State private var showingNewConversationSheet = false
    
    // State để hiển thị/ẩn paywall
    @State private var showingPaywall = false
    
    var body: some View {
        // NavigationStack: cho phép navigate giữa các màn hình
        NavigationStack {
            ZStack {
                // Nếu đang loading, hiển thị loading indicator
                if viewModel.isLoading {
                    ProgressView("Đang tải...")
                }
                // Nếu danh sách rỗng và không loading
                else if viewModel.conversations.isEmpty {
                    emptyStateView
                }
                // Hiển thị danh sách conversations
                else {
                    conversationListView
                }
            }
            .navigationTitle("Chat AI")
            .toolbar {
                // Nút Sign Out ở góc trái
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await authViewModel.signOut()
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                // Nút Upgrade to Premium
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingPaywall = true
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Premium")
                        }
                        .foregroundColor(.yellow)
                    }
                }
                
                // Nút "+" ở góc phải để tạo conversation mới
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewConversationSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            // Sheet để tạo conversation mới
            .sheet(isPresented: $showingNewConversationSheet) {
                NewConversationSheet(viewModel: viewModel)
            }
            // Sheet để hiển thị paywall
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            // Alert hiển thị lỗi (nếu có)
            .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            // Load conversations khi view xuất hiện
            .task {
                await viewModel.loadConversations()
            }
        }
    }
    
    // MARK: - Conversation List View
    
    /// View hiển thị danh sách conversations
    private var conversationListView: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                // NavigationLink: khi tap vào sẽ navigate đến ChatView
                NavigationLink(destination: ChatView(conversation: conversation)) {
                    ConversationRow(conversation: conversation)
                }
            }
            // Swipe để xóa
            .onDelete(perform: deleteConversations)
        }
        .listStyle(.plain)
        // Pull to refresh
        .refreshable {
            await viewModel.loadConversations()
        }
    }
    
    // MARK: - Empty State View
    
    /// View hiển thị khi chưa có conversation nào
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Chưa có cuộc hội thoại nào")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Nhấn nút + để bắt đầu chat với AI")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Xóa conversations
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = viewModel.conversations[index]
            Task {
                await viewModel.deleteConversation(conversation)
            }
        }
    }
}

// MARK: - Conversation Row

/// Row hiển thị thông tin một conversation
struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tiêu đề conversation
            Text(conversation.title)
                .font(.headline)
            
            // Thời gian cập nhật cuối
            Text(formatDate(conversation.updatedAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    /// Format date thành string dễ đọc
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - New Conversation Sheet

/// Sheet để tạo conversation mới
struct NewConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ConversationListViewModel
    
    @State private var title = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tiêu đề cuộc hội thoại", text: $title)
                } header: {
                    Text("Thông tin")
                } footer: {
                    Text("Ví dụ: Học Swift, Hỏi về lập trình, v.v.")
                }
            }
            .navigationTitle("Cuộc hội thoại mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Nút Cancel
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                
                // Nút Tạo
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tạo") {
                        Task {
                            await viewModel.createConversation(title: title.isEmpty ? "Cuộc hội thoại mới" : title)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConversationListView()
}

