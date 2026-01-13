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
    
    /// Lấy danh sách subscription plans với giá thật từ RevenueCat
    func getAvailablePlans() async throws -> [SubscriptionPlan] {
        let offerings = try await getOfferings()
        
        guard let currentOffering = offerings.current else {
            print("⚠️ No current offering found")
            // Trả về gói Free nếu không có offerings
            return [SubscriptionPlan(type: .free)]
        }
        
        print("📦 Current offering: \(currentOffering.identifier)")
        print("📦 Available packages count: \(currentOffering.availablePackages.count)")
        
        var plans: [SubscriptionPlan] = []
        
        // Luôn thêm gói Free đầu tiên
        plans.append(SubscriptionPlan(type: .free))
        
        // Duyệt qua các packages trong offering
        for package in currentOffering.availablePackages {
            let productId = package.storeProduct.productIdentifier
            let packageId = package.identifier
            
            print("📦 Package: \(packageId) → Product: \(productId)")
            
            // Map product ID với plan type
            if productId == "com.whales.freechat.yearly" {
                let plan = SubscriptionPlan(type: .yearly, package: package)
                plans.append(plan)
                print("✅ Added Yearly plan")
            } else if productId == "com.whales.freechat.monthly" {
                let plan = SubscriptionPlan(type: .monthly, package: package)
                plans.append(plan)
                print("✅ Added Monthly plan")
            } else if productId == "com.whales.freechat.weekly" {
                let plan = SubscriptionPlan(type: .weekly, package: package)
                plans.append(plan)
                print("✅ Added Weekly plan")
            } else {
                print("⚠️ Unknown product: \(productId)")
            }
        }
        
        print("✅ Loaded \(plans.count) subscription plans from RevenueCat")
        return plans
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
                    plan = SubscriptionPlan(type: .weekly)
                } else if productId.contains("monthly") {
                    plan = SubscriptionPlan(type: .monthly)
                } else {
                    plan = SubscriptionPlan(type: .free)
                }
                
                return SubscriptionStatus(
                    currentPlan: plan,
                    isActive: true,
                    expirationDate: entitlement.expirationDate
                )
            }
            
            // Không có active subscription
            return SubscriptionStatus(
                currentPlan: SubscriptionPlan(type: .free),
                isActive: false,
                expirationDate: nil
            )
            
        } catch {
            print("❌ Error getting subscription status: \(error)")
            return SubscriptionStatus(
                currentPlan: SubscriptionPlan(type: .free),
                isActive: false,
                expirationDate: nil
            )
        }
    }
}

