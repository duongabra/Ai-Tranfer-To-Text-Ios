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
            "com.whales.freechat.yearly",
            "com.whales.freechat.monthly"
        ]
        
        let products = try await Product.products(for: productIds)
        
        var plans: [SubscriptionPlan] = []
        
        // Luôn thêm gói Free
        plans.append(SubscriptionPlan(type: .free))
        
        // Convert StoreKit Products thành SubscriptionPlan
        for product in products {
            if product.id == "com.whales.freechat.yearly" {
                let plan = SubscriptionPlan(
                    type: .yearly,
                    storeKitProduct: product
                )
                plans.append(plan)
            } else if product.id == "com.whales.freechat.monthly" {
                let plan = SubscriptionPlan(
                    type: .monthly,
                    storeKitProduct: product
                )
                plans.append(plan)
            } else if product.id == "com.whales.freechat.weekly" {
                let plan = SubscriptionPlan(
                    type: .weekly,
                    storeKitProduct: product
                )
                plans.append(plan)
            }
        }
        
        return plans
    }
    
    // MARK: - Purchase
    
    /// Mua một subscription
    func purchase(product: Product) async throws {
        print("🛒 [StoreKitService] Initiating purchase for: \(product.id)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify transaction
            switch verification {
            case .verified(let transaction):
                print("✅ [StoreKitService] Purchase successful!")
                print("   - Product ID: \(transaction.productID)")
                print("   - Transaction ID: \(transaction.id)")
                print("   - Purchase Date: \(transaction.purchaseDate)")
                if let expirationDate = transaction.expirationDate {
                    print("   - Expiration Date: \(expirationDate)")
                }
                await transaction.finish()
            case .unverified(let transaction, let error):
                print("⚠️ [StoreKitService] Purchase unverified:")
                print("   - Product ID: \(transaction.productID)")
                print("   - Error: \(error)")
                await transaction.finish()
            }
            
        case .userCancelled:
            print("⚠️ [StoreKitService] User cancelled purchase")
            throw StoreKitError.userCancelled
            
        case .pending:
            print("⏳ [StoreKitService] Purchase pending approval")
            throw StoreKitError.purchasePending
            
        @unknown default:
            print("❌ [StoreKitService] Unknown purchase result")
            throw StoreKitError.unknown
        }
    }
    
    // MARK: - Check Subscription Status
    
    /// Kiểm tra product ID nào đang active (user đã mua)
    /// - Returns: Product ID của gói đang active, hoặc nil nếu chưa mua gói nào
    func getCurrentSubscriptionProductId() async -> String? {
        print("🔍 [StoreKitService] Checking current subscription...")
        
        // StoreKit 2: Lấy tất cả transactions hiện tại
        var foundActiveSubscription = false
        for await result in Transaction.currentEntitlements {
            // Verify transaction
            switch result {
            case .verified(let transaction):
                print("📦 [StoreKitService] Found transaction: \(transaction.productID)")
                print("   - Product Type: \(transaction.productType)")
                print("   - Purchase Date: \(transaction.purchaseDate)")
                
                // Kiểm tra xem transaction có phải subscription không
                // và có còn active không (chưa expire)
                if transaction.productType == .autoRenewable {
                    if let expirationDate = transaction.expirationDate {
                        print("   - Expiration Date: \(expirationDate)")
                        print("   - Is Expired: \(expirationDate <= Date())")
                        
                        if expirationDate > Date() {
                            print("✅ [StoreKitService] Active subscription found: \(transaction.productID)")
                            foundActiveSubscription = true
                            return transaction.productID
                        } else {
                            print("⚠️ [StoreKitService] Subscription expired: \(transaction.productID)")
                        }
                    } else {
                        print("   - No expiration date")
                    }
                }
                
            case .unverified(let transaction, let error):
                print("⚠️ [StoreKitService] Unverified transaction: \(transaction.productID) - \(error)")
                continue
            }
        }
        
        if !foundActiveSubscription {
            print("❌ [StoreKitService] No active subscription found")
        }
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

