//
//  ChatViewModel.swift
//  Chat-Ai
//
//  ViewModel quản lý state và logic cho màn hình chat
//

import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    
    @Published var messages: [Message] = []        // Danh sách messages trong conversation
    @Published var inputText = ""                  // Text đang nhập trong ô input
    @Published var isLoading = false               // Đang load messages?
    @Published var isSending = false               // Đang gửi message?
    @Published var errorMessage: String?           // Thông báo lỗi
    
    let conversation: Conversation                 // Conversation hiện tại
    
    /// Initializer
    /// - Parameter conversation: Conversation cần hiển thị
    init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    /// Load tất cả messages của conversation
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            messages = try await SupabaseService.shared.fetchMessages(conversationId: conversation.id)
        } catch {
            errorMessage = "Không thể tải tin nhắn: \(error.localizedDescription)"
            print("❌ Error loading messages: \(error)")
        }
        
        isLoading = false
    }
    
    /// Gửi message của user và nhận phản hồi từ AI
    func sendMessage() async {
        // Kiểm tra input có rỗng không
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // Clear input ngay lập tức để user có thể gõ message tiếp
        inputText = ""
        isSending = true
        errorMessage = nil
        
        do {
            // Bước 1: Lưu message của user vào database
            let userMessage = try await SupabaseService.shared.createMessage(
                conversationId: conversation.id,
                role: .user,
                content: messageText
            )
            
            // Thêm message của user vào danh sách
            messages.append(userMessage)
            
            // Bước 2: Gửi tất cả messages đến AI để lấy context
            let aiResponse = try await AIService.shared.sendMessage(messages: messages)
            
            // Bước 3: Lưu phản hồi của AI vào database
            let assistantMessage = try await SupabaseService.shared.createMessage(
                conversationId: conversation.id,
                role: .assistant,
                content: aiResponse
            )
            
            // Thêm message của AI vào danh sách
            messages.append(assistantMessage)
            
            // Bước 4: Cập nhật updated_at của conversation
            try await SupabaseService.shared.updateConversationTimestamp(conversationId: conversation.id)
            
        } catch let error as AIError where error == .missingAPIKey {
            // Lỗi đặc biệt: chưa có API key
            errorMessage = error.localizedDescription
        } catch {
            // Các lỗi khác
            errorMessage = "Không thể gửi tin nhắn: \(error.localizedDescription)"
            print("❌ Error sending message: \(error)")
        }
        
        isSending = false
    }
}

