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
    
    // ✅ File attachment
    @Published var selectedFile: FileAttachment?   // File đã chọn (chưa gửi)
    @Published var isUploadingFile = false         // Đang upload file?
    
    // ✅ Conversation title (có thể thay đổi khi rename)
    @Published var conversationTitle: String
    
    let conversation: Conversation                 // Conversation hiện tại
    
    /// Initializer
    /// - Parameter conversation: Conversation cần hiển thị
    init(conversation: Conversation) {
        self.conversation = conversation
        self.conversationTitle = conversation.title // Khởi tạo title
    }
    
    /// Load tất cả messages của conversation
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            messages = try await SupabaseService.shared.fetchMessages(conversationId: conversation.id)
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
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
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            // Các lỗi khác
            errorMessage = "Không thể gửi tin nhắn: \(error.localizedDescription)"
            print("❌ Error sending message: \(error)")
        }
        
        isSending = false
    }
    
    // MARK: - File Attachment
    
    /// Upload file và gửi message có file đính kèm
    /// - Parameters:
    ///   - data: Data của file
    ///   - fileName: Tên file
    ///   - fileType: Loại file
    func sendMessageWithFile(data: Data, fileName: String, fileType: FileAttachment.FileType) async {
        isSending = true
        isUploadingFile = true
        errorMessage = nil
        
        do {
            // Bước 1: Upload file lên Supabase Storage
            let fileURL = try await StorageService.shared.uploadFile(
                data: data,
                fileName: fileName,
                fileType: fileType
            )
            
            isUploadingFile = false
            
            // Bước 2: Tạo message với file attachment
            let messageContent = inputText.isEmpty ? "📎 Sent a file" : inputText
            inputText = "" // Clear input
            
            let userMessage = try await SupabaseService.shared.createMessage(
                conversationId: conversation.id,
                role: .user,
                content: messageContent,
                fileUrl: fileURL,
                fileName: fileName,
                fileType: fileType.rawValue,
                fileSize: data.count
            )
            
            // Thêm message vào danh sách
            messages.append(userMessage)
            
            // Clear selected file
            selectedFile = nil
            
            // Bước 3: Gửi đến AI
            // ✅ Nếu có ảnh → Dùng Gemini (hỗ trợ vision)
            let aiResponse: String
            
            if fileType == .image {
                // Gửi ảnh + text đến Gemini
                let prompt = messageContent == "📎 Sent a file" ? "Hãy mô tả ảnh này chi tiết" : messageContent
                aiResponse = try await GeminiService.shared.sendMessageWithImage(
                    text: prompt,
                    imageData: data
                )
            } else if !messageContent.isEmpty && messageContent != "📎 Sent a file" {
                // Chỉ có text → Dùng AI service thường
                aiResponse = try await AIService.shared.sendMessage(messages: messages)
            } else {
                // Video/Audio không có text → Không gửi AI
                isSending = false
                isUploadingFile = false
                return
            }
            
            // Lưu AI response
            let assistantMessage = try await SupabaseService.shared.createMessage(
                conversationId: conversation.id,
                role: .assistant,
                content: aiResponse
            )
            
            messages.append(assistantMessage)
            
            // Bước 4: Cập nhật timestamp
            try await SupabaseService.shared.updateConversationTimestamp(conversationId: conversation.id)
            
        } catch let error as StorageError {
            errorMessage = error.localizedDescription
            print("❌ Storage error: \(error)")
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Không thể gửi file: \(error.localizedDescription)"
            print("❌ Error sending file: \(error)")
        }
        
        isSending = false
        isUploadingFile = false
    }
    
    /// Chọn file để gửi (preview trước khi gửi)
    /// - Parameter attachment: File attachment
    func selectFile(_ attachment: FileAttachment) {
        selectedFile = attachment
    }
    
    /// Hủy file đã chọn
    func cancelFileSelection() {
        selectedFile = nil
    }
    
    /// Xóa tất cả messages trong conversation (giữ lại conversation)
    func clearAllMessages() async {
        do {
            // Xóa tất cả messages trong database
            try await SupabaseService.shared.deleteAllMessages(conversationId: conversation.id)
            
            // Clear local array
            messages.removeAll()
            
            print("✅ Cleared all messages in conversation")
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Không thể xóa tin nhắn: \(error.localizedDescription)"
            print("❌ Error clearing messages: \(error)")
        }
    }
    
    /// Xóa conversation (bao gồm cả messages)
    func deleteConversation() async {
        do {
            // Xóa conversation trong database (messages sẽ tự động xóa do CASCADE)
            try await SupabaseService.shared.deleteConversation(id: conversation.id)
            
            print("✅ Deleted conversation")
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Không thể xóa cuộc hội thoại: \(error.localizedDescription)"
            print("❌ Error deleting conversation: \(error)")
        }
    }
    
    /// Đổi tên conversation
    func renameConversation(newTitle: String) async {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        do {
            // Update title trong database
            try await SupabaseService.shared.updateConversationTitle(
                conversationId: conversation.id,
                newTitle: trimmedTitle
            )
            
            // ✅ Update local title để UI tự động refresh
            conversationTitle = trimmedTitle
            
            print("✅ Renamed conversation to: \(trimmedTitle)")
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Không thể đổi tên: \(error.localizedDescription)"
            print("❌ Error renaming conversation: \(error)")
        }
    }
}

