//
//  StoreKitService.swift
//  Chat-Ai
//
//  Service dùng StoreKit 2 thuần (cho Simulator)
//

import Foundation
import StoreKit

// MARK: - StoreKitService

actor StoreKitService {
    
    static let shared = StoreKitService()
    
    private init() {}
    
    // MARK: - Get Available Plans
    
    /// Lấy danh sách subscription plans từ StoreKit 2
    func getAvailablePlans() async throws -> [SubscriptionPlan] {
        // Load products từ StoreKit Configuration
        let productIds = [
            "com.whales.freechat.weekly",
            "com.whales.freechat.monthly"
        ]
        
        print("📦 Requesting products: \(productIds)")
        
        let products = try await Product.products(for: productIds)
        
        print("📦 Received \(products.count) products from StoreKit")
        for product in products {
            print("  - \(product.id): \(product.displayName) - \(product.displayPrice)")
        }
        
        var plans: [SubscriptionPlan] = []
        
        // Luôn thêm gói Free
        plans.append(SubscriptionPlan(type: .free))
        
        // Convert StoreKit Products thành SubscriptionPlan
        for product in products {
            if product.id == "com.whales.freechat.weekly" {
                let plan = SubscriptionPlan(
                    type: .weekly,
                    storeKitProduct: product
                )
                plans.append(plan)
                print("✅ Added Weekly plan: \(product.displayPrice)")
            } else if product.id == "com.whales.freechat.monthly" {
                let plan = SubscriptionPlan(
                    type: .monthly,
                    storeKitProduct: product
                )
                plans.append(plan)
                print("✅ Added Monthly plan: \(product.displayPrice)")
            }
        }
        
        print("✅ Loaded \(plans.count) plans from StoreKit 2")
        return plans
    }
    
    // MARK: - Purchase
    
    /// Mua một subscription
    func purchase(product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify transaction
            switch verification {
            case .verified(let transaction):
                print("✅ Purchase successful: \(transaction.productID)")
                await transaction.finish()
            case .unverified(let transaction, let error):
                print("⚠️ Purchase unverified: \(error)")
                await transaction.finish()
            }
            
        case .userCancelled:
            print("⚠️ User cancelled purchase")
            throw StoreKitError.userCancelled
            
        case .pending:
            print("⏳ Purchase pending")
            throw StoreKitError.purchasePending
            
        @unknown default:
            throw StoreKitError.unknown
        }
    }
    
    // MARK: - Check Subscription Status
    
    /// Kiểm tra product ID nào đang active (user đã mua)
    /// - Returns: Product ID của gói đang active, hoặc nil nếu chưa mua gói nào
    func getCurrentSubscriptionProductId() async -> String? {
        // StoreKit 2: Lấy tất cả transactions hiện tại
        for await result in Transaction.currentEntitlements {
            // Verify transaction
            switch result {
            case .verified(let transaction):
                // Kiểm tra xem transaction có phải subscription không
                // và có còn active không (chưa expire)
                if transaction.productType == .autoRenewable,
                   let expirationDate = transaction.expirationDate,
                   expirationDate > Date() {
                    print("📱 Found active subscription: \(transaction.productID)")
                    return transaction.productID
                }
                
            case .unverified:
                continue
            }
        }
        
        print("📱 No active subscription found")
        return nil
    }
}

// MARK: - StoreKitError

enum StoreKitError: Error, LocalizedError {
    case userCancelled
    case purchasePending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

