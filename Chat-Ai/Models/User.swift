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
    var avatarURL: String?    // Avatar URL (từ Supabase user_profiles.avatar_url)
    var firstName: String?    // Từ Supabase user_profiles.first_name
    var lastName: String?     // Từ Supabase user_profiles.last_name

    // CodingKeys: map giữa Swift property và JSON keys
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

