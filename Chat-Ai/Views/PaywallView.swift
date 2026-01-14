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
        
        // ✅ TẠM THỜI: Dùng StoreKit 2 trực tiếp từ StoreKit Configuration file
        // Sau này sẽ chuyển sang RevenueCat Dashboard khi đã ổn định
        do {
            // Bước 1: Lấy danh sách plans từ StoreKit 2 (tạm thời)
            availablePlans = try await StoreKitService.shared.getAvailablePlans()
            
            // Bước 2: Check subscription status từ StoreKit 2
            let currentProductId = await StoreKitService.shared.getCurrentSubscriptionProductId()
            
            // Log subscription status để test
            print("📱 [PaywallView] Current subscription status:")
            print("   - Product ID: \(currentProductId ?? "none")")
            if let productId = currentProductId {
                if productId.contains("yearly") {
                    print("   - Plan: Yearly")
                } else if productId.contains("monthly") {
                    print("   - Plan: Monthly")
                } else if productId.contains("weekly") {
                    print("   - Plan: Weekly")
                } else {
                    print("   - Plan: Unknown (\(productId))")
                }
            } else {
                print("   - Plan: No active subscription")
            }
            
            // Bước 3: Đánh dấu gói đang active
            availablePlans = availablePlans.map { plan in
                var updatedPlan = plan
                updatedPlan.isCurrentPlan = (plan.type.rawValue == currentProductId)
                return updatedPlan
            }
            
            // Auto-select Yearly (nếu chưa mua) hoặc gói khác (nếu đã mua)
            if currentProductId == nil {
                // Chưa mua → chọn Yearly
                selectedPlan = availablePlans.first(where: { $0.type == .yearly })
                print("📱 [PaywallView] Auto-selected: Yearly (no active subscription)")
            } else {
                // Đã mua → chọn gói khác để upgrade/downgrade
                selectedPlan = availablePlans.first(where: { !$0.isCurrentPlan && $0.isPremium })
                print("📱 [PaywallView] Auto-selected: \(selectedPlan?.type ?? .free) (upgrade/downgrade)")
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load plans: \(error.localizedDescription)"
            isLoading = false
        }
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
                // ✅ TẠM THỜI: Dùng StoreKit 2 trực tiếp
                guard let product = selectedPlan.storeKitProduct else {
                    errorMessage = "Product not available"
                    isLoading = false
                    return
                }
                
                print("🛒 [PaywallView] Starting purchase...")
                print("   - Product ID: \(product.id)")
                print("   - Product Name: \(product.displayName)")
                print("   - Price: \(product.displayPrice)")
                
                // Purchase qua StoreKit 2
                try await StoreKitService.shared.purchase(product: product)
                
                print("✅ [PaywallView] Purchase successful!")
                
                // Check subscription status sau khi purchase
                let newProductId = await StoreKitService.shared.getCurrentSubscriptionProductId()
                print("📱 [PaywallView] Subscription status after purchase:")
                print("   - Product ID: \(newProductId ?? "none")")
                if let productId = newProductId {
                    print("   - Plan: \(productId)")
                } else {
                    print("   - Plan: No active subscription (may need to wait for transaction to process)")
                }
                
                // Refresh subscription status sau khi purchase
                await SubscriptionViewModel.shared.refreshSubscriptionStatus()
                
                isLoading = false
                dismiss() // Đóng paywall
                
            } catch {
                print("❌ [PaywallView] Purchase failed: \(error.localizedDescription)")
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Restore Purchases Action
    
    private func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // StoreKit 2 tự động restore purchases khi check Transaction.currentEntitlements
            // Chỉ cần reload plans để check subscription status mới nhất
            await loadPlans()
            isLoading = false
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
                    if isYearlyPlan {
                        // Gói năm: Hiển thị "$199 /yr" và "$16.6 / mo"
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(plan.price) /yr")
                                .font(.custom("Overused Grotesk", size: 20))
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryOrange)
                            
                            Text("$16.6 / mo")
                                .font(.custom("Overused Grotesk", size: 14))
                                .fontWeight(.regular)
                                .foregroundColor(.textTertiary)
                        }
                    } else {
                        // Gói tháng: Hiển thị "$29 /mo"
                        Text("\(plan.price) /mo")
                            .font(.custom("Overused Grotesk", size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryOrange)
                    }
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
