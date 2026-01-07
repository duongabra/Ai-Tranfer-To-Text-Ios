//
//  RevenueCatService.swift
//  Chat-Ai
//
//  Service quản lý subscription với RevenueCat
//

import Foundation
import RevenueCat

// MARK: - RevenueCatService

actor RevenueCatService {
    
    static let shared = RevenueCatService()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure RevenueCat với API key
    /// Gọi function này khi app launch
    func configure() {
        // API key từ Config.xcconfig → AppConfig
        let apiKey = AppConfig.revenueCatAPIKey
        
        // Configure RevenueCat
        Purchases.logLevel = .debug // Bật debug log để dễ debug
        Purchases.configure(withAPIKey: apiKey)
        
        print("✅ RevenueCat configured successfully")
    }
    
    // MARK: - Get Offerings
    
    /// Lấy danh sách offerings (subscription products) từ RevenueCat
    func getOfferings() async throws -> Offerings {
        return try await Purchases.shared.offerings()
    }
    
    // MARK: - Purchase
    
    /// Mua một subscription package
    /// - Parameter package: Package cần mua (từ offerings)
    /// - Returns: CustomerInfo sau khi mua thành công
    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo
    }
    
    // MARK: - Restore Purchases
    
    /// Khôi phục purchases (khi user đã mua trên device khác hoặc reinstall app)
    func restorePurchases() async throws -> CustomerInfo {
        return try await Purchases.shared.restorePurchases()
    }
    
    // MARK: - Get Customer Info
    
    /// Lấy thông tin subscription hiện tại của user
    func getCustomerInfo() async throws -> CustomerInfo {
        return try await Purchases.shared.customerInfo()
    }
    
    // MARK: - Check Subscription Status
    
    /// Kiểm tra user có active subscription không
    func hasActiveSubscription() async -> Bool {
        do {
            let customerInfo = try await getCustomerInfo()
            
            // Check xem có entitlement "premium" active không
            // (Entitlement sẽ config trong RevenueCat Dashboard)
            if let entitlement = customerInfo.entitlements["premium"],
               entitlement.isActive {
                return true
            }
            
            return false
        } catch {
            print("❌ Error checking subscription: \(error)")
            return false
        }
    }
    
    /// Lấy subscription status chi tiết
    func getSubscriptionStatus() async -> SubscriptionStatus {
        do {
            let customerInfo = try await getCustomerInfo()
            
            // Check premium entitlement
            if let entitlement = customerInfo.entitlements["premium"],
               entitlement.isActive {
                
                // Xác định plan hiện tại dựa vào product identifier
                let productId = entitlement.productIdentifier
                let plan: SubscriptionPlan
                
                if productId.contains("weekly") {
                    plan = .weekly
                } else if productId.contains("monthly") {
                    plan = .monthly
                } else {
                    plan = .free
                }
                
                return SubscriptionStatus(
                    currentPlan: plan,
                    isActive: true,
                    expirationDate: entitlement.expirationDate
                )
            }
            
            // Không có active subscription
            return SubscriptionStatus(
                currentPlan: .free,
                isActive: false,
                expirationDate: nil
            )
            
        } catch {
            print("❌ Error getting subscription status: \(error)")
            return SubscriptionStatus(
                currentPlan: .free,
                isActive: false,
                expirationDate: nil
            )
        }
    }
}

