//
//  SubscriptionViewModel.swift
//  Chat-Ai
//
//  ViewModel quản lý subscription state với RevenueCat
//

import Foundation
import RevenueCat

@MainActor
class SubscriptionViewModel: ObservableObject {
    
    static let shared = SubscriptionViewModel()
    
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Cache key cho UserDefaults
    private let cacheKey = "subscriptionStatusCache"
    private let cacheTimestampKey = "subscriptionStatusCacheTimestamp"
    private let cacheExpirationInterval: TimeInterval = 300 // 5 phút
    
    private init() {
        // Load từ cache khi khởi động
        loadFromCache()
    }
    
    // MARK: - Load Subscription Status
    
    /// Load subscription status từ RevenueCat (và cache lại)
    func refreshSubscriptionStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let status = await RevenueCatService.shared.getSubscriptionStatus()
            
            // Cập nhật state
            subscriptionStatus = status
            
            // Cache lại
            saveToCache(status)
            
        } catch {
            errorMessage = "Failed to load subscription: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Load subscription status từ cache hoặc RevenueCat
    func loadSubscriptionStatus(forceRefresh: Bool = false) async {
        // Nếu không force refresh và cache còn valid → dùng cache
        if !forceRefresh, let cached = loadFromCache(), isCacheValid() {
            subscriptionStatus = cached
            return
        }
        
        // Load từ RevenueCat
        await refreshSubscriptionStatus()
    }
    
    // MARK: - Check Subscription
    
    /// Kiểm tra user có active subscription không
    func hasActiveSubscription() -> Bool {
        return subscriptionStatus?.isActive ?? false
    }
    
    /// Kiểm tra user có quyền truy cập premium không
    func hasPremiumAccess() -> Bool {
        return subscriptionStatus?.hasAccess ?? false
    }
    
    /// Lấy plan hiện tại
    func getCurrentPlan() -> SubscriptionPlan {
        return subscriptionStatus?.currentPlan ?? SubscriptionPlan(type: .free)
    }
    
    /// Lấy expiration date
    func getExpirationDate() -> Date? {
        return subscriptionStatus?.expirationDate
    }
    
    // MARK: - Cache Management
    
    /// Lưu subscription status vào cache
    private func saveToCache(_ status: SubscriptionStatus) {
        // Lưu timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        
        // Lưu status (chỉ lưu các thông tin cần thiết)
        let cacheData: [String: Any] = [
            "isActive": status.isActive,
            "planType": status.currentPlan.type.rawValue,
            "expirationDate": status.expirationDate?.timeIntervalSince1970 ?? 0
        ]
        UserDefaults.standard.set(cacheData, forKey: cacheKey)
    }
    
    /// Load subscription status từ cache
    @discardableResult
    private func loadFromCache() -> SubscriptionStatus? {
        guard let cacheData = UserDefaults.standard.dictionary(forKey: cacheKey),
              let isActive = cacheData["isActive"] as? Bool,
              let planTypeString = cacheData["planType"] as? String,
              let planType = SubscriptionPlan.PlanType(rawValue: planTypeString) else {
            return nil
        }
        
        let expirationDate: Date?
        if let expirationTimestamp = cacheData["expirationDate"] as? TimeInterval,
           expirationTimestamp > 0 {
            expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
        } else {
            expirationDate = nil
        }
        
        let plan = SubscriptionPlan(type: planType)
        let status = SubscriptionStatus(
            currentPlan: plan,
            isActive: isActive,
            expirationDate: expirationDate
        )
        
        subscriptionStatus = status
        return status
    }
    
    /// Kiểm tra cache còn valid không
    private func isCacheValid() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? TimeInterval else {
            return false
        }
        
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        return cacheAge < cacheExpirationInterval
    }
    
    /// Clear cache
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
}
