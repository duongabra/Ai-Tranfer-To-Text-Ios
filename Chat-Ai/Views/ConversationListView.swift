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
    
    // State để hiển thị/ẩn confirmation dialog xóa tất cả
    @State private var showingClearAllConfirmation = false
    
    var body: some View {
        // NavigationStack: cho phép navigate giữa các màn hình
        NavigationStack {
            ZStack {
                // Nếu đang loading, hiển thị loading indicator
                if viewModel.isLoading {
                    ProgressView("Loading...")
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
                
                // Nút Clear All (chỉ hiện khi có conversations)
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.conversations.isEmpty {
                        Button(action: {
                            showingClearAllConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
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
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            // Confirmation dialog xóa tất cả
            .confirmationDialog("Delete all conversations?", isPresented: $showingClearAllConfirmation, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    Task {
                        await viewModel.clearAllConversations()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All conversations and messages will be permanently deleted.")
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
            
            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to start chatting with AI")
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
                    TextField("Conversation title", text: $title)
                } header: {
                    Text("Info")
                } footer: {
                    Text("Example: Learn Swift, Ask about programming, etc.")
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Nút Cancel
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Nút Tạo
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.createConversation(title: title.isEmpty ? "New Conversation" : title)
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

