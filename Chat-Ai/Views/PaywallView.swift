//
//  PaywallView.swift
//  Chat-Ai
//
//  Màn hình chọn gói subscription (Paywall)
//

import SwiftUI
import RevenueCat
import StoreKit

struct PaywallView: View {
    
    @Environment(\.dismiss) var dismiss
    @State private var availablePlans: [SubscriptionPlan] = []
    @State private var selectedPlan: SubscriptionPlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Subscription info khi đã có gói
    @State private var currentProductId: String?
    @State private var expirationDate: Date?
    @State private var nextPaymentDate: Date?
    @State private var hasActiveSubscription = false
    @State private var isSubscriptionCancelled = false
    @State private var showManageSubscriptions = false
    
    var body: some View {
        ZStack {
            // Background màu #D87757
            Color.primaryOrange.opacity(0.05)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Group Icon (thay art_illustration)
                    Image(hasActiveSubscription ? "Group_4" : "art_illustration")
                        .resizable()
                        .scaledToFit()
                        .frame(width: hasActiveSubscription ? 96 : 358, height: hasActiveSubscription ? 96 : 200)
                        .padding(.top, 16)
                    
                    // MARK: - Title + Description
                    if hasActiveSubscription {
                        // Có subscription: căn giữa
                        VStack(alignment: .center, spacing: 4) {
                            Text("You're on Pro")
                                .font(.custom("Overused Grotesk", size: 24))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(32 - 24) // line-height: 32px
                            
                            Text("Full access is active on this account.")
                                .font(.custom("Overused Grotesk", size: 14))
                                .fontWeight(.regular)
                                .monospacedDigit()
                                .foregroundColor(.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(20 - 14) // line-height: 20px
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                    } else {
                        // Chưa có subscription: căn trái
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
                    }
                    
                    // MARK: - Subscription Info Card (chỉ hiển thị khi có subscription)
                    if hasActiveSubscription, let productId = currentProductId, let expirationDate = expirationDate {
                        // Tìm plan tương ứng để lấy price từ product
                        let currentPlan = availablePlans.first(where: { $0.id == productId })
                        SubscriptionInfoCard(
                            productId: productId,
                            expirationDate: expirationDate,
                            nextPaymentDate: nextPaymentDate ?? expirationDate,
                            isCancelled: isSubscriptionCancelled,
                            planPrice: currentPlan?.price ?? ""
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // MARK: - Subscription Details & Terms (Required by Apple) - Moved to top
                    if !hasActiveSubscription {
                        VStack(spacing: 12) {
                            // Subscription details card
                            if let plan = selectedPlan ?? availablePlans.first(where: { $0.type == .monthly }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Subscription Details")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.semibold))
                                        .foregroundColor(.textPrimary)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text("Title:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(.textTertiary)
                                                .frame(width: 60, alignment: .leading)
                                            Text(plan.title)
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(.textPrimary)
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Text("Length:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(.textTertiary)
                                                .frame(width: 60, alignment: .leading)
                                            Text(plan.duration)
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(.textPrimary)
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Text("Price:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(.textTertiary)
                                                .frame(width: 60, alignment: .leading)
                                            Text(plan.price)
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(.textPrimary)
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Text("Type:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(.textTertiary)
                                                .frame(width: 60, alignment: .leading)
                                            Text("Auto-renewable subscription")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(.textPrimary)
                                        }
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E4E4E4"), lineWidth: 1)
                                )
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                            
                            // Terms and Privacy Policy
                            HStack(spacing: 4) {
                                Text("By subscribing, you agree to our")
                                    .font(Font.custom("Overused Grotesk", size: 11).weight(.regular))
                                    .foregroundColor(.textTertiary)
                                
                                Button(action: {
                                    openURL("https://quick-vid-read.lovable.app/terms")
                                }) {
                                    Text("Terms of Service")
                                        .font(Font.custom("Overused Grotesk", size: 11).weight(.regular))
                                        .foregroundColor(.primaryOrange)
                                        .underline()
                                }
                                
                                Text("and")
                                    .font(Font.custom("Overused Grotesk", size: 11).weight(.regular))
                                    .foregroundColor(.textTertiary)
                                
                                Button(action: {
                                    openURL("https://quick-vid-read.lovable.app/privacy")
                                }) {
                                    Text("Privacy Policy")
                                        .font(Font.custom("Overused Grotesk", size: 11).weight(.regular))
                                        .foregroundColor(.primaryOrange)
                                        .underline()
                                }
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                    
                    // MARK: - Features (chỉ hiển thị khi chưa có subscription)
                    if !hasActiveSubscription {
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
                    }
                    
                    // MARK: - Plans (chỉ hiển thị khi chưa có subscription)
                    if !hasActiveSubscription {
                        if isLoading && availablePlans.isEmpty {
                            ProgressView("Loading plans...")
                                .padding()
                        } else {
                            VStack(spacing: 12) {
                                // Sắp xếp: monthly lên trước, sau đó weekly
                                ForEach(availablePlans.filter { $0.isPremium }.sorted { plan1, plan2 in
                                    if plan1.type == .monthly { return true }
                                    if plan2.type == .monthly { return false }
                                    if plan1.type == .weekly { return true }
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
                    }
                    
                    // MARK: - Buttons
                    VStack(spacing: 8) {
                        if hasActiveSubscription {
                            // Khi đã có subscription: Manage Plan và Back to Home
                            // Primary Button: Manage Plan
                            Button(action: {
                                managePlan()
                            }) {
                                Text("Manage Plan")
                                    .font(.custom("Overused Grotesk", size: 16))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.primaryOrange)
                                    .foregroundColor(.textWhite)
                                    .cornerRadius(16)
                            }
                            
                            // Secondary Button: Back to Home
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Back to Home")
                                    .font(.custom("Overused Grotesk", size: 16))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                        } else {
                            // Khi chưa có subscription: Upgrade to Pro và Not now
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
                    
                    // MARK: - Terms & Policy (Bottom links)
                    HStack(spacing: 8) {
                        Button(action: {
                            openURL("https://quick-vid-read.lovable.app/terms")
                        }) {
                            Text("Terms & Conditions")
                                .font(Font.custom("Overused Grotesk", size: 13).weight(.regular))
                                .foregroundColor(.textTertiary)
                        }
                        
                        Rectangle()
                            .fill(Color.borderGray)
                            .frame(width: 1, height: 12)
                        
                        Button(action: {
                            openURL("https://quick-vid-read.lovable.app/privacy")
                        }) {
                            Text("Privacy Policy")
                                .font(Font.custom("Overused Grotesk", size: 13).weight(.regular))
                                .foregroundColor(.textTertiary)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .onChange(of: showManageSubscriptions) { newValue in
            // Khi manage subscriptions sheet đóng (từ true -> false), reload subscription status
            // Dùng state để track giá trị cũ
            if !newValue && showManageSubscriptions {
                Task {
                    await loadPlans()
                }
            }
        }
        .task {
            await loadPlans()
        }
        .onAppear {
            // Ensure plans are loaded when view appears
            if availablePlans.isEmpty {
                Task {
                    await loadPlans()
                }
            }
        }
    }
    
    // MARK: - Open URL
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // Mở trong Safari với options để đảm bảo link hoạt động
        UIApplication.shared.open(url, options: [.universalLinksOnly: false]) { success in
            if !success {
                print("❌ [PaywallView] Failed to open URL: \(urlString)")
            }
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
            if let subscriptionInfo = await StoreKitService.shared.getCurrentSubscriptionInfo() {
                hasActiveSubscription = true
                currentProductId = subscriptionInfo.productId
                expirationDate = subscriptionInfo.expirationDate
                isSubscriptionCancelled = subscriptionInfo.isCancelled
                nextPaymentDate = subscriptionInfo.expirationDate // Next payment = expiration date (khi auto-renew)
                
                // Log subscription status để test
                print("📱 [PaywallView] Current subscription status:")
                print("   - Product ID: \(subscriptionInfo.productId)")
                print("   - Expiration Date: \(subscriptionInfo.expirationDate)")
                print("   - Is Cancelled: \(subscriptionInfo.isCancelled)")
                print("   - Next Payment Date: \(nextPaymentDate?.description ?? "none")")
                
                // Đánh dấu gói đang active
                availablePlans = availablePlans.map { plan in
                    var updatedPlan = plan
                    updatedPlan.isCurrentPlan = (plan.type.rawValue == subscriptionInfo.productId)
                    return updatedPlan
                }
                
                // Auto-select cùng loại gói để extend (weekly -> weekly, monthly -> monthly)
                // Cho phép chọn cả gói đang active để extend
                let currentPlanType = subscriptionInfo.productId.contains("weekly") ? SubscriptionPlan.PlanType.weekly : 
                                     subscriptionInfo.productId.contains("monthly") ? SubscriptionPlan.PlanType.monthly : nil
                
                if let currentPlanType = currentPlanType {
                    // Ưu tiên chọn cùng loại gói (có thể là gói đang active)
                    selectedPlan = availablePlans.first(where: { $0.type == currentPlanType })
                }
                
                // Nếu không tìm thấy cùng loại, chọn gói khác
                if selectedPlan == nil {
                    selectedPlan = availablePlans.first(where: { $0.isPremium })
                }
                
                print("📱 [PaywallView] Auto-selected: \(selectedPlan?.type ?? .free) (extend plan)")
            } else {
                hasActiveSubscription = false
                currentProductId = nil
                expirationDate = nil
                nextPaymentDate = nil
                
                print("📱 [PaywallView] No active subscription")
                
                // Auto-select Monthly (nếu chưa mua)
                selectedPlan = availablePlans.first(where: { $0.type == .monthly })
                print("📱 [PaywallView] Auto-selected: Monthly (no active subscription)")
            }
            
            isLoading = false
        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = "Failed to load plans: \(errorDesc)"
            print("❌ [PaywallView] Error loading plans: \(error)")
            isLoading = false
            
            // Nếu không có products, hiển thị message rõ ràng hơn
            if let storeKitError = error as? StoreKitError, storeKitError == .productsNotFound {
                errorMessage = "Subscription products are not available. Please check your internet connection and try again."
            }
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
    
    // MARK: - Manage Plan Action
    
    private func managePlan() {
        print("⚙️ [PaywallView] Opening manage subscriptions sheet...")
        
        // Mở manage subscriptions sheet để user có thể quản lý subscription
        showManageSubscriptions = true
    }
    
    // MARK: - Cancel Subscription Action
    
    private func cancelSubscription() {
        print("🚫 [PaywallView] Opening manage subscriptions sheet...")
        
        // Mở manage subscriptions sheet để user có thể cancel trực tiếp trong app
        showManageSubscriptions = true
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
    
    // Monthly plan = gói tháng (luôn có background cam nhạt - Best value)
    // Weekly plan = gói tuần (background trắng)
    private var isMonthlyPlan: Bool {
        return plan.type == .monthly
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    // Title row với badge "Best value" cho monthly plan
                    HStack(alignment: .center, spacing: 6) {
                        Text(plan.title)
                            .font(.custom("Overused Grotesk", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        // Badge "30% Off" cho monthly plan (Best value)
                        if isMonthlyPlan && !plan.isCurrentPlan {
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
                        if isMonthlyPlan {
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
                            // Weekly plan không có description
                        }
                    }
                }
                
                Spacer()
                
                // Price column - Lấy giá trực tiếp từ product, không hardcode
                VStack(alignment: .trailing, spacing: 2) {
                    if isMonthlyPlan {
                        // Gói tháng: Hiển thị giá từ product
                        Text("\(plan.price) / mo")
                            .font(.custom("Overused Grotesk", size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryOrange)
                    } else {
                        // Gói tuần: Hiển thị giá từ product
                        Text("\(plan.price) / wk")
                            .font(.custom("Overused Grotesk", size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryOrange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                // Gói tháng (monthly) luôn có background cam nhạt - Best value
                // Gói tuần (weekly) background trắng
                isMonthlyPlan
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

// MARK: - Subscription Info Card

struct SubscriptionInfoCard: View {
    let productId: String
    let expirationDate: Date
    let nextPaymentDate: Date
    let isCancelled: Bool
    let planPrice: String // Lấy từ product, không hardcode
    
    private var planTitle: String {
        if productId.contains("weekly") {
            return "Weekly"
        } else if productId.contains("monthly") {
            return "Monthly"
        } else {
            return "Pro"
        }
    }
    
    private var planPriceDisplay: String {
        // Lấy giá từ product, thêm đơn vị dựa trên productId
        if planPrice.isEmpty {
            return ""
        }
        
        if productId.contains("weekly") {
            return "\(planPrice) / wk"
        } else if productId.contains("monthly") {
            return "\(planPrice) / mo"
        } else {
            return planPrice
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("\(planTitle) - \(planPriceDisplay)")
                .font(.custom("Overused Grotesk", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            HStack(spacing: 0) {
                Text(isCancelled ? "Access until: " : "Next payment: ")
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.regular)
                    .foregroundColor(.textTertiary) // #717171
                
                Text(formatDate(nextPaymentDate))
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.regular)
                    .foregroundColor(.textPrimary) // #020202
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primaryOrange.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
