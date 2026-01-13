//
//  PaywallView.swift
//  Chat-Ai
//
//  Màn hình chọn gói subscription (Paywall)
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    
    @Environment(\.dismiss) var dismiss
    @State private var availablePlans: [SubscriptionPlan] = []
    @State private var selectedPlan: SubscriptionPlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // MARK: - Header
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.custom("Overused Grotesk", size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Upgrade to Premium")
                            .font(.custom("Overused Grotesk", size: 34))
                            .fontWeight(.bold)
                        
                        Text("Unlock unlimited messages and GPT-4 access")
                            .font(.custom("Overused Grotesk", size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Plans
                    if isLoading && availablePlans.isEmpty {
                        ProgressView("Loading plans...")
                            .padding()
                    } else {
                        VStack(spacing: 15) {
                            ForEach(availablePlans.filter { $0.isPremium }) { plan in
                                PlanCard(
                                    plan: plan,
                                    isSelected: selectedPlan?.id == plan.id,
                                    onTap: {
                                        selectedPlan = plan
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // MARK: - Features
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Premium Features")
                            .font(.custom("Overused Grotesk", size: 17))
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "infinity", text: "Unlimited messages")
                        FeatureRow(icon: "brain.head.profile", text: "GPT-4 access")
                        FeatureRow(icon: "clock.arrow.circlepath", text: "Chat history saved forever")
                        FeatureRow(icon: "headphones", text: "Priority support")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // MARK: - Subscribe Button
                    Button(action: {
                        subscribeToPlan()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Subscribe to \(selectedPlan?.title ?? "Premium")")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedPlan != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || selectedPlan == nil)
                    .padding(.horizontal, 16)
                    
                    // MARK: - Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.custom("Overused Grotesk", size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // MARK: - Restore Purchases
                    Button(action: {
                        restorePurchases()
                    }) {
                        Text("Restore Purchases")
                            .font(.custom("Overused Grotesk", size: 13))
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                    
                    // MARK: - Terms
                    Text("Auto-renewable. Cancel anytime.")
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadPlans()
            }
        }
    }
    
    // MARK: - Load Plans
    
    private func loadPlans() async {
        isLoading = true
        errorMessage = nil
        
        // Detect Simulator vs Real Device
        #if targetEnvironment(simulator)
        // SIMULATOR: Dùng StoreKit 2 thuần
        print("📱 Running on Simulator - Using StoreKit 2")
        do {
            // Bước 1: Lấy danh sách plans
            availablePlans = try await StoreKitService.shared.getAvailablePlans()
            
            // Bước 2: Check xem user đã mua gói nào chưa
            let currentProductId = await StoreKitService.shared.getCurrentSubscriptionProductId()
            print("📱 Current subscription: \(currentProductId ?? "none")")
            
            // Bước 3: Đánh dấu gói đang active
            availablePlans = availablePlans.map { plan in
                var updatedPlan = plan
                // So sánh product ID của plan với product ID đang active
                updatedPlan.isCurrentPlan = (plan.type.rawValue == currentProductId)
                return updatedPlan
            }
            
            // Auto-select Monthly (nếu chưa mua)
            if currentProductId == nil {
                selectedPlan = availablePlans.first(where: { $0.type == .monthly })
            } else {
                // Nếu đã mua rồi, chọn gói khác (để upgrade/downgrade)
                selectedPlan = availablePlans.first(where: { !$0.isCurrentPlan && $0.isPremium })
            }
            
            isLoading = false
        } catch {
            print("❌ StoreKit error: \(error)")
            errorMessage = "Failed to load plans: \(error.localizedDescription)"
            isLoading = false
        }
        #else
        // REAL DEVICE: Dùng RevenueCat
        print("📱 Running on Real Device - Using RevenueCat")
        do {
            availablePlans = try await RevenueCatService.shared.getAvailablePlans()
            
            // Check current subscription từ RevenueCat
            let hasActiveSubscription = await RevenueCatService.shared.hasActiveSubscription()
            print("📱 Has active subscription: \(hasActiveSubscription)")
            
            // Auto-select Monthly
            if let monthlyPlan = availablePlans.first(where: { $0.type == .monthly }) {
                selectedPlan = monthlyPlan
            } else if let firstPremiumPlan = availablePlans.first(where: { $0.isPremium }) {
                selectedPlan = firstPremiumPlan
            }
            
            isLoading = false
        } catch {
            print("❌ RevenueCat error: \(error)")
            errorMessage = "Failed to load plans: \(error.localizedDescription)"
            isLoading = false
        }
        #endif
    }
    
    // MARK: - Subscribe Action
    
    private func subscribeToPlan() {
        guard let selectedPlan = selectedPlan else {
            errorMessage = "Please select a plan"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                #if targetEnvironment(simulator)
                // SIMULATOR: Dùng StoreKit 2
                guard let product = selectedPlan.storeKitProduct else {
                    errorMessage = "Product not available"
                    isLoading = false
                    return
                }
                try await StoreKitService.shared.purchase(product: product)
                #else
                // REAL DEVICE: Dùng RevenueCat
                guard let package = selectedPlan.package else {
                    errorMessage = "Package not available"
                    isLoading = false
                    return
                }
                _ = try await RevenueCatService.shared.purchase(package: package)
                #endif
                
                // Thành công!
                print("✅ Subscription successful!")
                isLoading = false
                dismiss() // Đóng paywall
                
            } catch {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                isLoading = false
                print("❌ Purchase error: \(error)")
            }
        }
    }
    
    // MARK: - Restore Purchases Action
    
    private func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await RevenueCatService.shared.restorePurchases()
                print("✅ Purchases restored successfully!")
                isLoading = false
                dismiss()
            } catch {
                errorMessage = "Restore failed: \(error.localizedDescription)"
                isLoading = false
                print("❌ Restore error: \(error)")
            }
        }
    }
    
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(plan.title)
                            .font(.custom("Overused Grotesk", size: 17))
                            .fontWeight(.semibold)
                        
                        // Tag "CURRENT PLAN" nếu đang dùng gói này
                        if plan.isCurrentPlan {
                            Text("CURRENT PLAN")
                                .font(.custom("Overused Grotesk", size: 11))
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        // Tag "BEST VALUE" cho Monthly
                        if plan.type == .monthly && !plan.isCurrentPlan {
                            Text("BEST VALUE")
                                .font(.custom("Overused Grotesk", size: 11))
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(plan.description)
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(plan.price)
                        .font(.custom("Overused Grotesk", size: 22))
                        .fontWeight(.bold)
                        .fontWeight(.bold)
                    
                    Text(plan.duration)
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        // Disable button nếu đang là current plan
        .disabled(plan.isCurrentPlan)
        .opacity(plan.isCurrentPlan ? 0.6 : 1.0)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.custom("Overused Grotesk", size: 15))
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}

