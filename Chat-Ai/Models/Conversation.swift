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
    var transcriptionId: UUID? // ID của transcription (nếu có)
    
    // CodingKeys: map giữa tên property trong Swift và tên column trong database
    // Vì Swift dùng camelCase (createdAt) còn database dùng snake_case (created_at)
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case transcriptionId = "transcription_id"
    }
    
    // Initializer để tạo một Conversation mới
    init(id: UUID = UUID(), userId: UUID, title: String, createdAt: Date = Date(), updatedAt: Date = Date(), transcriptionId: UUID? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transcriptionId = transcriptionId
    }
    
    // Custom decoder để handle user_id có thể là UUID string hoặc integer string
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode id (UUID)
        id = try container.decode(UUID.self, forKey: .id)
        
        // Decode userId - handle cả UUID string và integer string
        // Thử decode như string trước
        if let userIdString = try? container.decode(String.self, forKey: .userId) {
            if let uuid = UUID(uuidString: userIdString) {
                userId = uuid
            } else {
                // Nếu không phải UUID format, có thể là integer string từ API
                // Log warning và dùng UUID mặc định (workaround để tránh crash)
                print("test log log10 : Warning - user_id is not UUID format: \(userIdString)")
                print("test log log10 : Expected UUID format but got: \(userIdString)")
                print("test log log10 : Using fallback UUID (backend should fix this)")
                // Dùng UUID mặc định để tránh crash (không ideal nhưng cần thiết)
                userId = UUID() // Fallback UUID
            }
        } else if let userIdInt = try? container.decode(Int.self, forKey: .userId) {
            // Handle integer user_id (từ API backend)
            print("test log log10 : Warning - user_id is integer: \(userIdInt), expected UUID")
            print("test log log10 : Using fallback UUID (backend should fix this)")
            userId = UUID() // Fallback UUID
        } else {
            // Thử decode như UUID trực tiếp (default case)
            userId = try container.decode(UUID.self, forKey: .userId)
        }
        
        // Decode các field khác
        title = try container.decode(String.self, forKey: .title)
        
        // Decode createdAt với custom date formatter để handle nhiều format
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        
        if let date = Conversation.parseDate(from: createdAtString) {
            createdAt = date
        } else {
            // Fallback: dùng Date hiện tại
            print("test log log10 : Warning - Could not parse created_at: \(createdAtString), using current date")
            createdAt = Date()
        }
        
        // Handle updated_at có thể là null (dùng createdAt làm fallback)
        if let updatedAtString = try? container.decodeIfPresent(String.self, forKey: .updatedAt),
           let updatedAtValue = Conversation.parseDate(from: updatedAtString) {
            updatedAt = updatedAtValue
        } else {
            // Nếu null hoặc decode fail, dùng createdAt
            updatedAt = createdAt
        }
        
        transcriptionId = try container.decodeIfPresent(UUID.self, forKey: .transcriptionId)
    }
    
    // Helper function để parse date từ nhiều format
    private static func parseDate(from dateString: String) -> Date? {
        // Thử ISO8601 với fractional seconds và timezone
        let dateFormatter1 = ISO8601DateFormatter()
        dateFormatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        if let date = dateFormatter1.date(from: dateString) {
            return date
        }
        
        // Thử ISO8601 với fractional seconds nhưng không có timezone
        let dateFormatter2 = ISO8601DateFormatter()
        dateFormatter2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter2.date(from: dateString) {
            return date
        }
        
        // Thử ISO8601 không có fractional seconds nhưng có timezone
        let dateFormatter3 = ISO8601DateFormatter()
        dateFormatter3.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = dateFormatter3.date(from: dateString) {
            return date
        }
        
        // Thử ISO8601 không có fractional seconds và không có timezone
        let dateFormatter4 = ISO8601DateFormatter()
        dateFormatter4.formatOptions = [.withInternetDateTime]
        if let date = dateFormatter4.date(from: dateString) {
            return date
        }
        
        // Thử format đơn giản hơn với DateFormatter
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        simpleFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = simpleFormatter.date(from: dateString) {
            return date
        }
        
        // Thử format không có fractional seconds
        simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        if let date = simpleFormatter.date(from: dateString) {
            return date
        }
        
        // Thử format không có timezone
        simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return simpleFormatter.date(from: dateString)
    }
}

