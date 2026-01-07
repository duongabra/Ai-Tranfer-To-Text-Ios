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
    }
    
    // Initializer để tạo Message mới
    init(id: UUID = UUID(), conversationId: UUID, role: MessageRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

