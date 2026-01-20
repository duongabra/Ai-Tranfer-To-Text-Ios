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
    @Published var isTranscribing = false          // Đang transcribe audio/video?
    @Published var transcriptionProgress: String?  // Trạng thái transcribe
    
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
            
            errorMessage = "Cannot load messages: \(error.localizedDescription)"
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
            
            // Bước 2: Gửi 9 message gần nhất đến AI để lấy context
            let recentMessages = Array(messages.suffix(9))
            let aiResponse = try await AIService.shared.sendMessage(messages: recentMessages)
            
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
            errorMessage = "Cannot send message: \(error.localizedDescription)"
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
            
            // Bước 3: Xử lý theo loại file
            let aiResponse: String
            
            if fileType == .image {
                // ✅ Image → Dùng Gemini vision
                let prompt = messageContent == "📎 Sent a file" ? "Describe this image in detail" : messageContent
                aiResponse = try await GeminiService.shared.sendMessageWithImage(
                    text: prompt,
                    imageData: data
                )
            } else if fileType == .audio {
                // ✅ Audio → Chỉ transcribe, KHÔNG gửi AI (user tự gửi sau)
                isTranscribing = true
                transcriptionProgress = "Converting audio to text..."
                
                let userId = 8042467986 // Fixed user_id for transcribe API
                
                let result = try await TranscribeService.shared.transcribeAudio(
                    audioData: data,
                    fileName: fileName,
                    userId: userId
                )
                
                isTranscribing = false
                transcriptionProgress = nil
                
                // ✅ Tạo message với message text và lưu transcription URL để download sau
                // Lưu transcription URL vào fileUrl để user có thể download sau
                let transcriptionFileName = "transcript_\(Date().timeIntervalSince1970).txt"
                
                // Lưu vào Supabase với transcription URL
                let savedMessage = try await SupabaseService.shared.createMessage(
                    conversationId: conversation.id,
                    role: .assistant,
                    content: result.message,  // Dùng message text để hiển thị
                    fileUrl: result.transcriptionURL,  // Lưu S3 URL để download
                    fileName: transcriptionFileName,
                    fileType: "other",  // Transcription file là text file
                    fileSize: nil
                )
                
                messages.append(savedMessage)
                
                // ✅ DỪNG ở đây, KHÔNG gửi AI
                isSending = false
                isUploadingFile = false
                return
            } else if fileType == .video {
                // ✅ Video → Chỉ transcribe, KHÔNG gửi AI (user tự gửi sau)
                isTranscribing = true
                transcriptionProgress = "Converting video to text..."
                
                let userId = 8042467986 // Fixed user_id for transcribe API
                
                let result = try await TranscribeService.shared.transcribeVideoURL(
                    videoURL: fileURL,
                    userId: userId
                )
                
                isTranscribing = false
                transcriptionProgress = nil
                
                // ✅ Tạo message với message text và lưu transcription URL để download sau
                // Lưu transcription URL vào fileUrl để user có thể download sau
                let transcriptionFileName = "transcript_\(Date().timeIntervalSince1970).txt"
                
                // Lưu vào Supabase với transcription URL
                let savedMessage = try await SupabaseService.shared.createMessage(
                    conversationId: conversation.id,
                    role: .assistant,
                    content: result.message,  // Dùng message text để hiển thị
                    fileUrl: result.transcriptionURL,  // Lưu S3 URL để download
                    fileName: transcriptionFileName,
                    fileType: "other",  // Transcription file là text file
                    fileSize: nil
                )
                
                messages.append(savedMessage)
                
                // ✅ DỪNG ở đây, KHÔNG gửi AI
                isSending = false
                isUploadingFile = false
                return
            } else if !messageContent.isEmpty && messageContent != "📎 Sent a file" {
                // Chỉ có text → Dùng AI service thường với 9 message gần nhất
                let recentMessages = Array(messages.suffix(9))
                aiResponse = try await AIService.shared.sendMessage(messages: recentMessages)
            } else {
                // Không có gì để gửi AI
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
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot send file: \(error.localizedDescription)"
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
            
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot delete messages: \(error.localizedDescription)"
        }
    }
    
    /// Xóa conversation (bao gồm cả messages)
    func deleteConversation() async {
        do {
            // Xóa conversation trong database (messages sẽ tự động xóa do CASCADE)
            try await SupabaseService.shared.deleteConversation(id: conversation.id)
            
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot delete conversation: \(error.localizedDescription)"
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
            
        } catch {
            // ✅ Kiểm tra nếu là lỗi 401 Unauthorized → Logout
            if let supabaseError = error as? SupabaseError, supabaseError == .unauthorized {
                await AuthService.shared.handleUnauthorizedError()
                return
            }
            
            errorMessage = "Cannot rename: \(error.localizedDescription)"
        }
    }
}


