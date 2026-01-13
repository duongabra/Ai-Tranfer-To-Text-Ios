//
//  Conversation.swift
//  Chat-Ai
//
//  Model đại diện cho một cuộc hội thoại
//

import Foundation

// Struct Conversation đại diện cho một cuộc trò chuyện
// Identifiable: để SwiftUI có thể phân biệt các item trong List
// Codable: để chuyển đổi giữa Swift object và JSON (cho Supabase)
// Hashable: để có thể dùng trong NavigationPath
struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID              // ID duy nhất của cuộc hội thoại
    let userId: UUID          // ID của người dùng sở hữu cuộc hội thoại này
    var title: String         // Tiêu đề của cuộc hội thoại (ví dụ: "Chat về Swift")
    let createdAt: Date       // Thời gian tạo cuộc hội thoại
    var updatedAt: Date       // Thời gian cập nhật cuối cùng
    
    // CodingKeys: map giữa tên property trong Swift và tên column trong database
    // Vì Swift dùng camelCase (createdAt) còn database dùng snake_case (created_at)
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Initializer để tạo một Conversation mới
    init(id: UUID = UUID(), userId: UUID, title: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

