//
//  SubscriptionPlan.swift
//  Chat-Ai
//
//  Model định nghĩa các gói subscription
//

import Foundation

// MARK: - SubscriptionPlan

/// Định nghĩa các gói subscription
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case free = "free"
    case weekly = "com.whales.freechat.weekly"
    case monthly = "com.whales.freechat.monthly"
    
    var id: String { rawValue }
    
    // MARK: - Display Information
    
    /// Tên hiển thị của gói
    var title: String {
        switch self {
        case .free:
            return "Free"
        case .weekly:
            return "Weekly Premium"
        case .monthly:
            return "Monthly Premium"
        }
    }
    
    /// Mô tả gói
    var description: String {
        switch self {
        case .free:
            return "10 messages per day"
        case .weekly:
            return "Unlimited messages, GPT-4 access"
        case .monthly:
            return "Best value! Save 40% vs Weekly"
        }
    }
    
    /// Giá hiển thị (USD)
    var price: String {
        switch self {
        case .free:
            return "$0"
        case .weekly:
            return "$2.99"
        case .monthly:
            return "$9.99"
        }
    }
    
    /// Duration hiển thị
    var duration: String {
        switch self {
        case .free:
            return ""
        case .weekly:
            return "per week"
        case .monthly:
            return "per month"
        }
    }
    
    // MARK: - Features
    
    /// Danh sách tính năng của gói
    var features: [String] {
        switch self {
        case .free:
            return [
                "10 messages per day",
                "GPT-3.5 Turbo",
                "Basic support"
            ]
        case .weekly:
            return [
                "Unlimited messages",
                "GPT-4 access",
                "Save chat history",
                "Priority support"
            ]
        case .monthly:
            return [
                "All Weekly features",
                "Save 40%",
                "Early access to new features",
                "Premium support"
            ]
        }
    }
    
    /// Icon cho từng gói
    var icon: String {
        switch self {
        case .free:
            return "circle"
        case .weekly:
            return "star.fill"
        case .monthly:
            return "crown.fill"
        }
    }
    
    /// Màu sắc cho từng gói
    var accentColor: String {
        switch self {
        case .free:
            return "gray"
        case .weekly:
            return "blue"
        case .monthly:
            return "purple"
        }
    }
    
    /// Có phải gói premium không?
    var isPremium: Bool {
        return self != .free
    }
}

// MARK: - SubscriptionStatus

/// Trạng thái subscription của user
struct SubscriptionStatus {
    let currentPlan: SubscriptionPlan
    let isActive: Bool
    let expirationDate: Date?
    
    /// User có quyền truy cập premium không?
    var hasAccess: Bool {
        return currentPlan.isPremium && isActive
    }
}

