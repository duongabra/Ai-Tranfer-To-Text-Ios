//
//  Swatch.swift
//  Chat-Ai
//
//  Model đại diện cho Swatch từ API /api/mobile/swatches
//

import Foundation

/// Swatch response từ API
struct Swatch: Identifiable, Codable {
    let id: String
    let userId: String
    let status: SwatchStatus
    let errorMessage: String?
    let barefaceUrl: String
    let lipstickUrls: [String]
    let swatchUrl: String?
    let brand: String
    let product: String
    let shade: String?
    let hexCode: String?
    let score: Int?
    let aiDescription: String?
    var isFavorited: Bool
    let feedback: Bool?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case errorMessage = "error_message"
        case barefaceUrl = "bareface_url"
        case lipstickUrls = "lipstick_urls"
        case swatchUrl = "swatch_url"
        case brand
        case product
        case shade
        case hexCode = "hex_code"
        case score
        case aiDescription = "ai_description"
        case isFavorited = "is_favorited"
        case feedback
        case createdAt = "created_at"
    }

    /// Helper: lấy display name (product + shade nếu có)
    var displayName: String {
        if let shade = shade, !shade.isEmpty {
            return "\(product) - \(shade)"
        }
        return product
    }

    /// Helper: relative time ago string
    var timeAgoString: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30

        if months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        } else if weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

/// Status của swatch
enum SwatchStatus: String, Codable {
    case processing
    case completed
    case failed

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = SwatchStatus(rawValue: rawValue) ?? .processing
    }
}

/// Paginated list response từ API
struct SwatchListResponse: Codable {
    let items: [Swatch]
    let total: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize = "page_size"
        case hasMore = "has_more"
    }
}

/// Response từ toggle favorite
struct FavoriteToggleResponse: Codable {
    let swatchId: String
    let isFavorited: Bool

    enum CodingKeys: String, CodingKey {
        case swatchId = "swatch_id"
        case isFavorited = "is_favorited"
    }
}

/// Response từ feedback
struct FeedbackResponse: Codable {
    let swatchId: String
    let isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case swatchId = "swatch_id"
        case isLiked = "is_liked"
    }
}
