//
//  ConversationListViewModel.swift
//  Chat-Ai
//
//  ViewModel quản lý state và logic cho màn hình danh sách conversations
//

import Foundation

// @MainActor: đảm bảo tất cả updates chạy trên main thread (cần thiết cho UI)
// ObservableObject: cho phép SwiftUI observe và update UI khi state thay đổi
@MainActor
class ConversationListViewModel: ObservableObject {
    
    // @Published: khi giá trị thay đổi, SwiftUI sẽ tự động update UI
    @Published var conversations: [Conversation] = []  // Danh sách conversations
    @Published var isLoading = false                   // Đang load dữ liệu?
    @Published var errorMessage: String?               // Thông báo lỗi (nếu có)
    
    // ✅ Prevent multiple simultaneous loads
    private var loadTask: Task<Void, Never>?
    
    /// Load tất cả conversations từ database
    func loadConversations() async {
        // ✅ Skip nếu đang loading (tránh gọi nhiều lần)
        guard !isLoading else {
            return
        }
        
        // ✅ Cancel previous task nếu đang chạy
        loadTask?.cancel()
        
        // ✅ Reset isLoading về false khi cancel task cũ
        if loadTask != nil {
            isLoading = false
        }
        
        // ✅ Tạo task mới
        loadTask = Task {
            // Check lại sau khi task được tạo (có thể đã bị cancel)
            guard !Task.isCancelled else {
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            do {
                // Gọi service để fetch data
                conversations = try await SupabaseService.shared.fetchConversations()
                // Chỉ print khi task không bị cancel
                if !Task.isCancelled {
                    print("✅ Loaded \(conversations.count) conversations")
                }
            } catch is CancellationError {
                // Task bị cancel → Không làm gì, không in log
                return
            } catch {
                // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
                if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                    await AuthService.shared.handleUnauthorizedError()
                    return
                }
                
                // Chỉ hiển thị lỗi nếu task không bị cancel
                if !Task.isCancelled {
                    errorMessage = "Cannot load list: \(error.localizedDescription)"
                    print("❌ Error loading conversations: \(error)")
                }
            }
            
            // Chỉ reset isLoading nếu task không bị cancel
            if !Task.isCancelled {
                isLoading = false
            }
        }
        
        await loadTask?.value
    }
    
    /// Tạo conversation mới
    /// - Parameter title: Tiêu đề của conversation
    func createConversation(title: String) async {
        do {
            // Tạo conversation mới trong database
            let newConversation = try await SupabaseService.shared.createConversation(title: title)
            
            // Thêm vào đầu danh sách (conversation mới nhất)
            conversations.insert(newConversation, at: 0)
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot create conversation: \(error.localizedDescription)"
            print("❌ Error creating conversation: \(error)")
        }
    }
    
    /// Xóa conversation
    /// - Parameter conversation: Conversation cần xóa
    func deleteConversation(_ conversation: Conversation) async {
        do {
            // Xóa trong database
            try await SupabaseService.shared.deleteConversation(id: conversation.id)
            
            // Xóa khỏi danh sách local
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot delete: \(error.localizedDescription)"
            print("❌ Error deleting conversation: \(error)")
        }
    }
    
    /// Xóa tất cả conversations (1 lần)
    func clearAllConversations() async {
        do {
            // Xóa tất cả conversations trong database (1 API call)
            try await SupabaseService.shared.deleteAllConversations()
            
            // Clear local array
            conversations.removeAll()
            
            print("✅ Cleared all conversations")
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot delete: \(error.localizedDescription)"
            print("❌ Error clearing all conversations: \(error)")
        }
    }
}

