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
        // ✅ Cancel previous task nếu đang chạy
        loadTask?.cancel()
        
        // ✅ Tạo task mới
        loadTask = Task {
            // Skip nếu đang loading
            guard !isLoading else {
                print("⚠️ Already loading, skipping...")
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            do {
                // Gọi service để fetch data
                conversations = try await SupabaseService.shared.fetchConversations()
                print("✅ Loaded \(conversations.count) conversations")
            } catch is CancellationError {
                // ⚠️ Task bị cancel (pull-to-refresh bị hủy) → Không hiển thị lỗi
                print("⚠️ Load conversations cancelled")
            } catch {
                // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
                if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                    await AuthService.shared.handleUnauthorizedError()
                    return
                }
                
                // Nếu có lỗi khác, lưu message để hiển thị
                errorMessage = "Không thể tải danh sách: \(error.localizedDescription)"
                print("❌ Error loading conversations: \(error)")
            }
            
            isLoading = false
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
            
            errorMessage = "Không thể tạo cuộc hội thoại: \(error.localizedDescription)"
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
            
            errorMessage = "Không thể xóa: \(error.localizedDescription)"
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
            
            errorMessage = "Không thể xóa: \(error.localizedDescription)"
            print("❌ Error clearing all conversations: \(error)")
        }
    }
}

