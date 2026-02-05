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
            
            // Bước 2: Lấy transcription content nếu có và gửi transcription + 9 messages gần nhất lên AI
            print("test log log10 : ========== PREPARING MESSAGES FOR AI ==========")
            var messagesToSend: [Message] = []
            
            // Thêm 9 messages gần nhất (filter bỏ transcription file messages - fileType == "other")
            let filteredMessages = messages.filter { message in
                // Bỏ qua message có fileType == "other" (transcription file để download)
                return message.fileType != "other"
            }
            let recentMessages = Array(filteredMessages.suffix(9))
            print("test log log10 : 📝 Filtered messages: \(filteredMessages.count) (from total \(messages.count) messages)")
            print("test log log10 : 📝 Recent messages count: \(recentMessages.count) (excluding transcription file messages)")
            messagesToSend.append(contentsOf: recentMessages)
            
            // Nếu conversation có transcription_id, lấy transcription content và thêm vào đầu (như assistant message đầu tiên)
            // Transcription content sẽ được gửi như một assistant message trong conversation history
            if let transcriptionId = conversation.transcriptionId {
                print("test log log10 : ✅ Found transcription_id: \(transcriptionId)")
                if let transcriptionContent = try? await SupabaseService.shared.getTranscriptionContent(transcriptionId: transcriptionId) {
                    print("test log log10 : ✅ Transcription content retrieved, length: \(transcriptionContent.count) characters")
                    // Tạo message từ transcription content và thêm vào đầu danh sách
                    // Đảm bảo transcription content là assistant message đầu tiên
                    let transcriptionMessage = Message(
                        conversationId: conversation.id,
                        role: .assistant,
                        content: transcriptionContent,
                        createdAt: conversation.createdAt
                    )
                    messagesToSend.insert(transcriptionMessage, at: 0)
                    print("test log log10 : ✅ Added transcription message to send list (index 0)")
                } else {
                    print("test log log10 : ❌ Failed to get transcription content")
                }
            } else {
                print("test log log10 : ⚠️ No transcription_id in conversation")
            }
            
            // Gửi lên AI (tổng tối đa 10 items: 1 transcription + 9 messages)
            print("test log log10 : 📤 Total messages to send to AI: \(messagesToSend.count)")
            print("test log log10 : Expected: 1 transcription + 9 messages = 10 items")
            for (index, msg) in messagesToSend.enumerated() {
                let contentPreview = msg.content.count > 100 ? String(msg.content.prefix(100)) + "..." : msg.content
                print("test log log10 :   [\(index + 1)] role=\(msg.role.rawValue), content_length=\(msg.content.count), preview=\"\(contentPreview)\"")
            }
            print("test log log10 : ==============================================")
            let aiResponse = try await AIService.shared.sendMessage(messages: messagesToSend)
            
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
                // ✅ Audio → Transcribe (API sẽ tạo conversation mới và trả về conversation_id)
                // Note: Khi transcribe trong conversation đã tồn tại, API vẫn tạo conversation mới
                // User sẽ được navigate đến conversation mới đó
                isTranscribing = true
                transcriptionProgress = "Converting audio to text..."
                
                // Lấy user_id thật từ user đã đăng nhập
                guard let currentUser = await AuthService.shared.getCurrentUser() else {
                    throw TranscribeError.transcriptionFailed
                }
                let userId = currentUser.id.uuidString
                
                print("test log log10 : Using real user_id: \(userId)")
                
                let result = try await TranscribeService.shared.transcribeAudio(
                    audioData: data,
                    fileName: fileName,
                    userId: userId
                )
                
                isTranscribing = false
                transcriptionProgress = nil
                
                // Lấy conversation_id và transcription_id từ API response
                guard let conversationIdString = result.conversationId,
                      let conversationId = UUID(uuidString: conversationIdString) else {
                    print("test log log10 : Error - Missing conversation_id")
                    isSending = false
                    isUploadingFile = false
                    return
                }
                
                // Đợi một chút để đảm bảo conversation đã được tạo trong database
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                // Tạo assistant message với S3 link để user download transcript file
                let s3Link = result.s3Link ?? result.transcriptionURL
                if !s3Link.isEmpty {
                    let fileName = result.title?.appending(".txt") ?? "transcript.txt"
                    let messageContent = result.message ?? "Got it. I'm analyzing the video now. If you want, tell me your goal (learn the concept vs. just get highlights) and I'll tailor it."
                    
                    _ = try? await SupabaseService.shared.createMessage(
                        conversationId: conversationId,
                        role: .assistant,
                        content: messageContent,
                        fileUrl: s3Link,
                        fileName: fileName,
                        fileType: "other"
                    )
                    print("test log log10 : Created assistant message with S3 link")
                }
                
                // API đã tạo conversation mới, không cần xử lý gì thêm ở đây
                // User sẽ cần navigate đến conversation mới nếu cần
                // ✅ DỪNG ở đây, KHÔNG gửi AI (transcription đã được lưu trong bảng transcriptions)
                isSending = false
                isUploadingFile = false
                return
            } else if fileType == .video {
                // ✅ Video → Transcribe (API sẽ tạo conversation mới và trả về conversation_id)
                // Note: Khi transcribe trong conversation đã tồn tại, API vẫn tạo conversation mới
                // User sẽ được navigate đến conversation mới đó
                isTranscribing = true
                transcriptionProgress = "Converting video to text..."
                
                // Lấy user_id thật từ user đã đăng nhập
                guard let currentUser = await AuthService.shared.getCurrentUser() else {
                    throw TranscribeError.transcriptionFailed
                }
                let userId = currentUser.id.uuidString
                
                print("test log log10 : Using real user_id: \(userId)")
                
                let result = try await TranscribeService.shared.transcribeVideoURL(
                    videoURL: fileURL,
                    userId: userId
                )
                
                isTranscribing = false
                transcriptionProgress = nil
                
                // Lấy conversation_id và transcription_id từ API response
                guard let conversationIdString = result.conversationId,
                      let conversationId = UUID(uuidString: conversationIdString) else {
                    print("test log log10 : Error - Missing conversation_id")
                    isSending = false
                    isUploadingFile = false
                    return
                }
                
                // Đợi một chút để đảm bảo conversation đã được tạo trong database
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                // Tạo assistant message với S3 link để user download transcript file
                let s3Link = result.s3Link ?? result.transcriptionURL
                if !s3Link.isEmpty {
                    let fileName = result.title?.appending(".txt") ?? "transcript.txt"
                    let messageContent = result.message ?? "Got it. I'm analyzing the video now. If you want, tell me your goal (learn the concept vs. just get highlights) and I'll tailor it."
                    
                    _ = try? await SupabaseService.shared.createMessage(
                        conversationId: conversationId,
                        role: .assistant,
                        content: messageContent,
                        fileUrl: s3Link,
                        fileName: fileName,
                        fileType: "other"
                    )
                    print("test log log10 : Created assistant message with S3 link")
                }
                
                // API đã tạo conversation mới, không cần xử lý gì thêm ở đây
                // User sẽ cần navigate đến conversation mới nếu cần
                // ✅ DỪNG ở đây, KHÔNG gửi AI (transcription đã được lưu trong bảng transcriptions)
                isSending = false
                isUploadingFile = false
                return
            } else if !messageContent.isEmpty && messageContent != "📎 Sent a file" {
                // Chỉ có text → Dùng AI service với transcription + 9 message gần nhất
                print("test log log10 : ========== PREPARING MESSAGES FOR AI (with file) ==========")
                var messagesToSend: [Message] = []
                
                // Nếu conversation có transcription_id, lấy transcription content
                if let transcriptionId = conversation.transcriptionId {
                    print("test log log10 : ✅ Found transcription_id: \(transcriptionId)")
                    if let transcriptionContent = try? await SupabaseService.shared.getTranscriptionContent(transcriptionId: transcriptionId) {
                        print("test log log10 : ✅ Transcription content retrieved, length: \(transcriptionContent.count) characters")
                        // Tạo message từ transcription content
                        let transcriptionMessage = Message(
                            conversationId: conversation.id,
                            role: .assistant,
                            content: transcriptionContent,
                            createdAt: conversation.createdAt
                        )
                        messagesToSend.append(transcriptionMessage)
                        print("test log log10 : ✅ Added transcription message to send list (index 0)")
                    } else {
                        print("test log log10 : ❌ Failed to get transcription content")
                    }
                } else {
                    print("test log log10 : ⚠️ No transcription_id in conversation")
                }
                
                // Thêm 9 messages gần nhất (filter bỏ transcription file messages - fileType == "other")
                let filteredMessages = messages.filter { message in
                    // Bỏ qua message có fileType == "other" (transcription file để download)
                    return message.fileType != "other"
                }
                let recentMessages = Array(filteredMessages.suffix(9))
                print("test log log10 : 📝 Filtered messages: \(filteredMessages.count) (from total \(messages.count) messages)")
                print("test log log10 : 📝 Recent messages count: \(recentMessages.count) (excluding transcription file messages)")
                messagesToSend.append(contentsOf: recentMessages)
                
                // Gửi lên AI (tổng tối đa 10 items: 1 transcription + 9 messages)
                print("test log log10 : 📤 Total messages to send to AI: \(messagesToSend.count)")
                print("test log log10 : Expected: 1 transcription + 9 messages = 10 items")
                for (index, msg) in messagesToSend.enumerated() {
                    let contentPreview = msg.content.count > 100 ? String(msg.content.prefix(100)) + "..." : msg.content
                    print("test log log10 :   [\(index + 1)] role=\(msg.role.rawValue), content_length=\(msg.content.count), preview=\"\(contentPreview)\"")
                }
                print("test log log10 : =========================================================")
                aiResponse = try await AIService.shared.sendMessage(messages: messagesToSend)
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


