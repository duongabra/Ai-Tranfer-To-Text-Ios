//
//  RevenueCatService.swift
//  Chat-Ai
//
//  Service quản lý subscription với RevenueCat
//

import Foundation
import RevenueCat
import StoreKit

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
        Purchases.configure(withAPIKey: apiKey)
        
    }
    
    // MARK: - Get Offerings
    
    /// Lấy danh sách offerings (subscription products) từ RevenueCat
    func getOfferings() async throws -> Offerings {
        return try await Purchases.shared.offerings()
    }
    
    /// Lấy danh sách subscription plans với giá thật từ StoreKit 2
    /// TẠM THỜI: Dùng StoreKit 2 trực tiếp cho cả simulator và real device
    /// Sau này sẽ chuyển sang RevenueCat Dashboard khi đã ổn định
    func getAvailablePlans() async throws -> [SubscriptionPlan] {
        // Tạm thời dùng StoreKit 2 trực tiếp từ StoreKit Configuration file
        return try await getAvailablePlansFromStoreKit()
    }
    
    /// Lấy plans từ RevenueCat Dashboard
    private func getAvailablePlansFromRevenueCat() async throws -> [SubscriptionPlan] {
        let offerings = try await getOfferings()
        
        guard let currentOffering = offerings.current else {
            return [SubscriptionPlan(type: .free)]
        }
        
        
        var plans: [SubscriptionPlan] = []
        plans.append(SubscriptionPlan(type: .free))
        
        for package in currentOffering.availablePackages {
            let productId = package.storeProduct.productIdentifier
            
            if productId == "com.whales.freechat.yearly" {
                plans.append(SubscriptionPlan(type: .yearly, package: package))
            } else if productId == "com.whales.freechat.monthly" {
                plans.append(SubscriptionPlan(type: .monthly, package: package))
            } else if productId == "com.whales.freechat.weekly" {
                plans.append(SubscriptionPlan(type: .weekly, package: package))
            }
        }
        
        return plans
    }
    
    /// Lấy plans trực tiếp từ StoreKit 2 (StoreKit Configuration file)
    private func getAvailablePlansFromStoreKit() async throws -> [SubscriptionPlan] {
        
        let productIds = [
            "com.whales.freechat.yearly",
            "com.whales.freechat.monthly"
        ]
        
        let products = try await Product.products(for: productIds)
        
        for product in products {
        }
        
        var plans: [SubscriptionPlan] = []
        plans.append(SubscriptionPlan(type: .free))
        
        for product in products {
            if product.id == "com.whales.freechat.yearly" {
                plans.append(SubscriptionPlan(type: .yearly, storeKitProduct: product))
            } else if product.id == "com.whales.freechat.monthly" {
                plans.append(SubscriptionPlan(type: .monthly, storeKitProduct: product))
            }
        }
        
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
            return SubscriptionStatus(
                currentPlan: SubscriptionPlan(type: .free),
                isActive: false,
                expirationDate: nil
            )
        }
    }
}

