//
//  Message.swift
//  Chat-Ai
//
//  Model đại diện cho một tin nhắn trong cuộc hội thoại
//

import Foundation

// Struct Message đại diện cho một tin nhắn
struct Message: Identifiable, Codable {
    let id: UUID              // ID duy nhất của tin nhắn
    let conversationId: UUID  // ID của cuộc hội thoại chứa tin nhắn này
    let role: MessageRole     // Vai trò: user (người dùng) hoặc assistant (AI)
    let content: String       // Nội dung tin nhắn
    let createdAt: Date       // Thời gian tạo tin nhắn
    
    // ✅ File attachment (optional)
    let fileUrl: String?      // URL của file đã upload
    let fileName: String?     // Tên file gốc
    let fileType: String?     // Loại file: image, video, audio
    let fileSize: Int?        // Kích thước file (bytes)
    
    // Enum để định nghĩa vai trò của tin nhắn
    enum MessageRole: String, Codable {
        case user = "user"           // Tin nhắn từ người dùng
        case assistant = "assistant" // Tin nhắn từ AI
    }
    
    // CodingKeys: map giữa Swift property và database column
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
        case fileUrl = "file_url"
        case fileName = "file_name"
        case fileType = "file_type"
        case fileSize = "file_size"
    }
    
    // Initializer để tạo Message mới
    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        fileUrl: String? = nil,
        fileName: String? = nil,
        fileType: String? = nil,
        fileSize: Int? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.fileUrl = fileUrl
        self.fileName = fileName
        self.fileType = fileType
        self.fileSize = fileSize
    }
    
    // ✅ Helper: Kiểm tra message có file không
    var hasAttachment: Bool {
        return fileUrl != nil
    }
    
    // ✅ Helper: Lấy file attachment
    var attachment: FileAttachment? {
        guard let fileUrl = fileUrl,
              let fileName = fileName,
              let fileType = fileType else {
            return nil
        }
        return FileAttachment(
            url: fileUrl,
            name: fileName,
            type: FileAttachment.FileType(rawValue: fileType) ?? .other,
            size: fileSize
        )
    }
}

