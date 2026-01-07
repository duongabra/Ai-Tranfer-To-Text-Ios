//
//  User.swift
//  Chat-Ai
//
//  Model đại diện cho User (người dùng)
//

import Foundation

// Struct User đại diện cho người dùng đã đăng nhập
struct User: Identifiable, Codable {
    let id: UUID              // ID duy nhất của user (từ Supabase Auth)
    let email: String         // Email của user
    let createdAt: Date       // Thời gian tạo account
    
    // Optional: Thêm thông tin khác nếu cần
    var displayName: String?  // Tên hiển thị (từ Google)
    var avatarURL: String?    // Avatar URL (từ Google)
    
    // CodingKeys: map giữa Swift property và JSON keys
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

