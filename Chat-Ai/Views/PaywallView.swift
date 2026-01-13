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
        ZStack {
            // Background màu #D87757
            Color.primaryOrange.opacity(0.05)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Art Illustration
                    Image("art_illustration")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 358, height: 200)
                        // .padding(.top, 16)
                    
                    // MARK: - Title + Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Go Pro for Full Access")
                            .font(.custom("Overused Grotesk", size: 24))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(32 - 24) // line-height: 32px
                        
                        Text("Unlock the complete summary and chat deeper with the video content.")
                            .font(.custom("Overused Grotesk", size: 14))
                            .fontWeight(.regular)
                            .monospacedDigit()
                            .foregroundColor(.textTertiary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(20 - 14) // line-height: 20px
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    
                    // MARK: - Features
                    VStack(spacing: 8) {
                        FeatureRow(
                            icon: "video_camera_icon",
                            text: "Unlimited video analyzing"
                        )
                        FeatureRow(
                            icon: "document_icon",
                            text: "Build your knowledge library"
                        )
                        FeatureRow(
                            icon: "history_icon",
                            text: "Save hours with Pro Summarizes"
                        )
                    }
                    .environment(\.multilineTextAlignment, TextAlignment.center)
                    .environment(\.font, Font.custom("Overused Grotesk", size: 16)
                        .weight(.semibold)
                    )
                    .padding(.horizontal, 16)
                    
                    // MARK: - Plans
                    if isLoading && availablePlans.isEmpty {
                        ProgressView("Loading plans...")
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            // Sắp xếp: yearly lên trước, sau đó monthly
                            ForEach(availablePlans.filter { $0.isPremium }.sorted { plan1, plan2 in
                                if plan1.type == .yearly { return true }
                                if plan2.type == .yearly { return false }
                                if plan1.type == .monthly { return true }
                                return false
                            }) { plan in
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
                    
                    // MARK: - Buttons
                    VStack(spacing: 8) {
                        // Primary Button: Upgrade to Pro
                        Button(action: {
                            subscribeToPlan()
                        }) {
                            HStack(spacing: 8) {
                                Image("crown_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .padding(2)
                                
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .textWhite))
                                } else {
                                    Text("Upgrade to Pro")
                                        .font(.custom("Overused Grotesk", size: 16))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .padding(.leading, 10)
                            .background(Color.primaryOrange)
                            .foregroundColor(.textWhite)
                            .cornerRadius(16)
                        }
                        .disabled(isLoading || selectedPlan == nil)
                        
                        // Secondary Button: Not now
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Not now")
                                .font(.custom("Overused Grotesk", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.custom("Overused Grotesk", size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 0)
                    }
                    
                    // MARK: - Terms & Policy
                    HStack(spacing: 8) {
                        Button(action: {
                            // TODO: Open Terms & Conditions
                        }) {
                            Text("Terms & Conditions")
                                .font(.custom("Overused Grotesk", size: 13))
                                .fontWeight(.regular)
                                .foregroundColor(.textTertiary)
                        }
                        
                        Rectangle()
                            .fill(Color.borderGray)
                            .frame(width: 1, height: 12)
                        
                        Button(action: {
                            // TODO: Open Privacy Policy
                        }) {
                            Text("Privacy Policy")
                                .font(.custom("Overused Grotesk", size: 13))
                                .fontWeight(.regular)
                                .foregroundColor(.textTertiary)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadPlans()
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
            
            // Auto-select Yearly (nếu chưa mua)
            if currentProductId == nil {
                selectedPlan = availablePlans.first(where: { $0.type == .yearly })
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
            
            // Auto-select Yearly
            if let yearlyPlan = availablePlans.first(where: { $0.type == .yearly }) {
                selectedPlan = yearlyPlan
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
    
    // Yearly plan = gói năm (luôn có background cam nhạt)
    // Monthly plan = gói tháng (background trắng)
    private var isYearlyPlan: Bool {
        return plan.type == .yearly
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    // Title row với badge "Best value" cho yearly plan
                    HStack(alignment: .center, spacing: 6) {
                        Text(plan.title)
                            .font(.custom("Overused Grotesk", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        // Badge "30% Off" hoặc "Best value" cho yearly plan
                        if isYearlyPlan && !plan.isCurrentPlan {
                            HStack(spacing: 4) {
                                Image("Group_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.textWhite)
                                
                                Text("30% Off")
                                    .font(.custom("Overused Grotesk", size: 12))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textWhite)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primaryOrange)
                            .cornerRadius(16)
                        }
                    }
                    
                    // Description row
                    HStack(alignment: .center, spacing: 6) {
                        if isYearlyPlan {
                            Text("Best value")
                                .font(.custom("Overused Grotesk", size: 14))
                                .fontWeight(.regular)
                                .foregroundColor(.textTertiary)
                            
                            // Dot separator
                            Circle()
                                .fill(Color.primaryOrange)
                                .frame(width: 4, height: 4)
                            
                            Text("Unlimited analyzing")
                                .font(.custom("Overused Grotesk", size: 14))
                                .fontWeight(.regular)
                                .foregroundColor(.textTertiary)
                        } else {
                            // Monthly plan không có description
                        }
                    }
                }
                
                Spacer()
                
                // Price column
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.custom("Overused Grotesk", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryOrange)
                    
                    Text(plan.duration)
                        .font(.custom("Overused Grotesk", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                // Gói năm (weekly) luôn có background cam nhạt
                // Gói tháng (monthly) background trắng
                isYearlyPlan
                    ? Color.primaryOrange.opacity(0.1)
                    : Color.white
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        // Nếu chọn gói nào thì gói đó có border màu cam
                        isSelected
                            ? Color.primaryOrange
                            : Color(hex: "000000").opacity(0.05),
                        lineWidth: 1
                    )
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(plan.isCurrentPlan)
        .opacity(plan.isCurrentPlan ? 0.6 : 1.0)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)
            
            Text(text)
                .font(.custom("Overused Grotesk", size: 16))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(24 - 16) // line-height: 24px
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
