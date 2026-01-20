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
        
        let products = try await Product.products(for: productIds)
        
        // Nếu không có products, throw error để PaywallView có thể handle
        if products.isEmpty {
            throw StoreKitError.productsNotFound
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
            } else if product.id == "com.whales.freechat.monthly" {
                let plan = SubscriptionPlan(
                    type: .monthly,
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
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify transaction
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
            case .unverified(let transaction, let error):
                await transaction.finish()
            }
            
        case .userCancelled:
            throw StoreKitError.userCancelled
            
        case .pending:
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
                if transaction.productType == .autoRenewable {
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            await transaction.finish()
                            return transaction.productID
                        }
                    } else {
                        await transaction.finish()
                        return transaction.productID
                    }
                }
                
            case .unverified(let transaction, let error):
                continue
            }
        }
        
        return nil
    }
    
    /// Lấy thông tin subscription hiện tại (productId, expirationDate, isCancelled)
    /// - Returns: Tuple (productId, expirationDate, isCancelled) hoặc nil nếu không có subscription
    func getCurrentSubscriptionInfo() async -> (productId: String, expirationDate: Date, isCancelled: Bool)? {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productType == .autoRenewable {
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        // Kiểm tra renewal status từ Product.SubscriptionInfo
                        var isCancelled = false
                        
                        if let product = try? await Product.products(for: [transaction.productID]).first,
                           let subscriptionInfo = product.subscription {
                            // Check renewal state từ subscription status
                            // subscriptionInfo.status có thể là async property
                            do {
                                let statuses = try await subscriptionInfo.status
                                for status in statuses {
                                    switch status.state {
                                    case .expired, .revoked:
                                        isCancelled = true
                                    case .subscribed:
                                        // Check renewal info để xem có auto-renew không
                                        // renewalInfo là VerificationResult, cần unwrap
                                        switch status.renewalInfo {
                                        case .verified(let renewalInfo):
                                            if renewalInfo.willAutoRenew == false {
                                                isCancelled = true
                                            }
                                        case .unverified:
                                            // Không thể verify renewal info, giả định chưa cancel
                                            break
                                        }
                                    default:
                                        break
                                    }
                                }
                            } catch {
                                // Error accessing subscription status
                            }
                            
                            return (transaction.productID, expirationDate, isCancelled)
                        }
                    }
                }
            case .unverified:
                continue
            }
        }
        
        return nil
    }
    
    /// Cancel subscription renewal (không hủy ngay, chỉ hủy auto-renewal)
    func cancelSubscription() async throws {
        // StoreKit 2: Cancel subscription thông qua App Store Settings
        // Không thể cancel trực tiếp trong app, phải redirect user đến Settings
        // Hoặc dùng StoreKit 2's manageSubscriptionsSheet
        throw StoreKitError.cannotCancelInApp
    }
}

// MARK: - StoreKitError

enum StoreKitError: Error, LocalizedError {
    case userCancelled
    case purchasePending
    case unknown
    case cannotCancelInApp
    case productsNotFound
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .unknown:
            return "Unknown error occurred"
        case .cannotCancelInApp:
            return "Please cancel subscription in Settings"
        case .productsNotFound:
            return "Subscription products not found. Please check App Store Connect configuration."
        }
    }
}

