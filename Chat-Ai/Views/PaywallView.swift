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
        ZStack(alignment: .topLeading) {
            Color.white
                .ignoresSafeArea()
            
            if hasActiveSubscription {
                // Đã subscribe: scroll chỉ header + 2 card; nút + links cố định ở cuối màn hình
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header (Figma 55499-2457)
                            HStack(spacing: 16) {
                                Button(action: { dismiss() }) {
                                    Image("subscription_back_icon")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "99A1AF"))
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer(minLength: 0)
                                Text("Subscription Info")
                                    .font(.custom("Overused Grotesk", size: 18))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(hex: "101828"))
                                Spacer(minLength: 0)
                                Color.clear.frame(width: 32, height: 32)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity)
                            
                            // Card 1: LipMatch Pro
                            if let productId = currentProductId, let expirationDate = expirationDate {
                                let currentPlan = availablePlans.first(where: { $0.id == productId })
                                let planTitle = productId.contains("weekly") ? "Weekly plan" : "Monthly plan"
                                let priceLine = productId.contains("weekly")
                                    ? "\(currentPlan?.price ?? "") pay per week"
                                    : "\(currentPlan?.price ?? "") pay per month"
                                let renewText = isSubscriptionCancelled
                                    ? "Access until: \(formatRenewDate(expirationDate))"
                                    : "Renews at \(formatRenewDate(nextPaymentDate ?? expirationDate))"
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LipMatch Pro")
                                        .font(.custom("Overused Grotesk", size: 20))
                                        .fontWeight(.medium)
                                        .foregroundColor(Color(hex: "101828"))
                                    VStack(alignment: .leading, spacing: 8) {
                                        SubscriptionInfoRow(assetIcon: "diamond_subscription", text: planTitle)
                                        SubscriptionInfoRow(systemName: "creditcard", text: priceLine)
                                        SubscriptionInfoRow(systemName: "arrow.clockwise", text: renewText)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "F9FAFB"))
                                .overlay(alignment: .bottomTrailing) {
                                    Image("lipmatch_decor")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 115, height: 101)
                                }
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "E5E7EB"), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 20)
                            }
                            
                            // Card 2: You have unlimited access to
                            VStack(alignment: .leading, spacing: 12) {
                                Text("You have unlimited access to:")
                                    .font(.custom("Overused Grotesk", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(hex: "101828"))
                                VStack(alignment: .leading, spacing: 8) {
                                    FeatureRow(icon: "check_line", text: "Unlimited lipstick try-ons")
                                    FeatureRow(icon: "check_line", text: "Fine-tune color depth & lip edges.")
                                    FeatureRow(icon: "check_line", text: "Save, revisit, and compare anytime.")
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "E5E7EB"), lineWidth: 1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                    
                    // Khối cố định cuối màn hình: nút Manage Plan + Terms & Policy
                    VStack(spacing: 12) {
                        Button(action: { managePlan() }) {
                            Text("Manage Plan")
                                .font(.custom("Overused Grotesk", size: 16))
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "030712"))
                                .foregroundColor(Color(hex: "F9FAFB"))
                                .cornerRadius(9999)
                        }
                        HStack(spacing: 8) {
                            Button(action: { openURL("https://quick-vid-read.lovable.app/terms") }) {
                                Text("Terms & Conditions")
                                    .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                    .foregroundColor(Color(hex: "6A7282"))
                            }
                            Rectangle()
                                .fill(Color(hex: "D1D5DC"))
                                .frame(width: 1, height: 12)
                            Button(action: { openURL("https://quick-vid-read.lovable.app/privacy") }) {
                                Text("Privacy Policy")
                                    .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                    .foregroundColor(Color(hex: "6A7282"))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 0)
                    .background(Color.white)
                }
            } else {
            ScrollView {
                VStack(spacing: 20) {
                    // Chưa subscribe
                        // MARK: - Group Icon (chưa subscribe)
                        Image("art_illustration")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 358, height: 200)
                            .padding(.top, 20)
                    }
                    
                    if !hasActiveSubscription {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Go Pro - Try any lipstick with AI")
                                .font(.custom("Overused Grotesk", size: 24))
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "101828"))
                                .multilineTextAlignment(.leading)
                            
                            Text("Get faster results, more edits, and unlimited try-ons. Upgrade anytime.")
                                .font(.custom("Overused Grotesk", size: 14))
                                .fontWeight(.regular)
                                .foregroundColor(Color(hex: "6A7282"))
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Features (Figma: lipstick, ai, check + label-sm #101828)
                    if !hasActiveSubscription {
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "lipstick_icon", text: "Unlimited lipstick try-ons")
                            FeatureRow(icon: "fine_tune_icon", text: "Fine-tune color depth & lip edges.")
                            FeatureRow(icon: "check_line", text: "Save, revisit, and compare anytime.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
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
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // MARK: - Subscription Details & Terms (Required by Apple) — below plan selection
                    if !hasActiveSubscription {
                        VStack(spacing: 12) {
                            if let plan = selectedPlan ?? availablePlans.first(where: { $0.type == .monthly }) ?? availablePlans.first {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Subscription Details")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.semibold))
                                        .foregroundColor(Color(hex: "101828"))
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text("Title:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(Color(hex: "6A7282"))
                                                .frame(width: 60, alignment: .leading)
                                            Text(plan.title)
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(Color(hex: "101828"))
                                        }
                                        HStack(spacing: 8) {
                                            Text("Length:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(Color(hex: "6A7282"))
                                                .frame(width: 60, alignment: .leading)
                                            Text(plan.duration)
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(Color(hex: "101828"))
                                        }
                                        HStack(spacing: 8) {
                                            Text("Price:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(Color(hex: "6A7282"))
                                                .frame(width: 60, alignment: .leading)
                                            Text(plan.price)
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(Color(hex: "101828"))
                                        }
                                        HStack(spacing: 8) {
                                            Text("Type:")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                                .foregroundColor(Color(hex: "6A7282"))
                                                .frame(width: 60, alignment: .leading)
                                            Text("Auto-renewable subscription")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(Color(hex: "101828"))
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
                            }
                            // HStack(spacing: 4) {
                            //     Text("By subscribing, you agree to our")
                            //         .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                            //         .foregroundColor(Color(hex: "6A7282"))
                            //     Button(action: { openURL("https://quick-vid-read.lovable.app/terms") }) {
                            //         Text("Terms of Service")
                            //             .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                            //             .foregroundColor(Color(hex: "101828"))
                            //             .underline()
                            //     }
                            //     Text("and")
                            //         .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                            //         .foregroundColor(Color(hex: "6A7282"))
                            //     Button(action: { openURL("https://quick-vid-read.lovable.app/privacy") }) {
                            //         Text("Privacy Policy")
                            //             .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                            //             .foregroundColor(Color(hex: "101828"))
                            //             .underline()
                            //     }
                            // }
                            // .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Buttons (chưa subscribe: Upgrade to Pro)
                    VStack(spacing: 12) {
                            Button(action: { subscribeToPlan() }) {
                                HStack(spacing: 8) {
                                    Image("VIP_2_fill")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(Color(hex: "F9FAFB"))
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "F9FAFB")))
                                    } else {
                                        Text("Upgrade to Pro")
                                            .font(.custom("Overused Grotesk", size: 16))
                                            .fontWeight(.medium)
                                            .foregroundColor(Color(hex: "F9FAFB"))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .padding(.leading, 10)
                                .background(Color(hex: "030712"))
                                .cornerRadius(9999)
                            }
                            .disabled(isLoading || selectedPlan == nil)
                            
                            // Button(action: { dismiss() }) {
                            //     Text("Not now")
                            //         .font(.custom("Overused Grotesk", size: 16))
                            //         .fontWeight(.medium)
                            //         .foregroundColor(Color(hex: "101828"))
                            // }
                            // .frame(maxWidth: .infinity)
                            // .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.custom("Overused Grotesk", size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 0)
                    }
                    
                    // MARK: - Terms & Policy (Figma: body-xs #6A7282, gap 8, separator #D1D5DC)
                    HStack(spacing: 8) {
                        Button(action: { openURL("https://quick-vid-read.lovable.app/terms") }) {
                            Text("Terms & Conditions")
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                .foregroundColor(Color(hex: "6A7282"))
                        }
                        Rectangle()
                            .fill(Color(hex: "D1D5DC"))
                            .frame(width: 1, height: 12)
                        Button(action: { openURL("https://quick-vid-read.lovable.app/privacy") }) {
                            Text("Privacy Policy")
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.regular))
                                .foregroundColor(Color(hex: "6A7282"))
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            
            // MARK: - Close button (top-left, chỉ khi chưa subscribe; khi đã subscribe dùng back trong header)
            if !hasActiveSubscription {
                Button(action: { dismiss() }) {
                    Image("paywall_close_icon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .padding(8)
                }
                .background(Color.white.opacity(0.3))
                .clipShape(Circle())
                .padding(.top, 8)
                .padding(.leading, 20)
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
        UIApplication.shared.open(url, options: [.universalLinksOnly: false])
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
                
            } else {
                hasActiveSubscription = false
                currentProductId = nil
                expirationDate = nil
                nextPaymentDate = nil
                
                // Auto-select Monthly (nếu chưa mua)
                selectedPlan = availablePlans.first(where: { $0.type == .monthly })
            }
            
            isLoading = false
        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = "Failed to load plans: \(errorDesc)"
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
                
                
                // Purchase qua StoreKit 2
                try await StoreKitService.shared.purchase(product: product)
                
                // Check subscription status sau khi purchase
                let newProductId = await StoreKitService.shared.getCurrentSubscriptionProductId()
                // Refresh subscription status sau khi purchase
                await SubscriptionViewModel.shared.refreshSubscriptionStatus()
                
                isLoading = false
                dismiss() // Đóng paywall
                
            } catch {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Manage Plan Action
    
    private func managePlan() {
        // Mở manage subscriptions sheet để user có thể quản lý subscription
        showManageSubscriptions = true
    }
    
    private func formatRenewDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM, yyyy"
        return f.string(from: date)
    }
    
    // MARK: - Cancel Subscription Action
    
    private func cancelSubscription() {
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

// MARK: - Plan Card (Figma: white bg, border selected #101828 / unselected #E5E7EB, radius 12, padding 12×16, price 28px #101828)

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    private var isMonthlyPlan: Bool { plan.type == .monthly }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(plan.title)
                            .font(.custom("Overused Grotesk", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "101828"))
                        
                        if isMonthlyPlan && !plan.isCurrentPlan {
                            Text("Best value")
                                .font(.custom("Overused Grotesk", size: 11))
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "F9FAFB"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "030712"))
                                .cornerRadius(4)
                        }
                    }
                    if isMonthlyPlan {
                        Text("Unlimited analyzing")
                            .font(.custom("Overused Grotesk", size: 14))
                            .fontWeight(.regular)
                            .foregroundColor(Color(hex: "6A7282"))
                    }
                }
                
                Spacer()
                
                if isMonthlyPlan {
                    HStack(alignment: .top, spacing: 6) {
                        Text(plan.price)
                            .font(.custom("Overused Grotesk", size: 28))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "101828"))
                        Text("/mo")
                            .font(.custom("Overused Grotesk", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "101828"))
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        Text(plan.price)
                            .font(.custom("Overused Grotesk", size: 28))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "101828"))
                        Text("/wk")
                            .font(.custom("Overused Grotesk", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "101828"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: "101828") : Color(hex: "E5E7EB"),
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Subscription Info Row (Figma: icon 20×20 + body-sm #101828, for subscribed state cards)

struct SubscriptionInfoRow: View {
    var assetIcon: String? = nil
    var systemName: String? = nil
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let asset = assetIcon {
                Image(asset)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 16)
                    .foregroundColor(Color(hex: "101828"))
            } else if let sys = systemName {
                Image(systemName: sys)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: "101828"))
                    .frame(width: 20, height: 20)
            }
            Text(text)
                .font(.custom("Overused Grotesk", size: 14))
                .fontWeight(.regular)
                .foregroundColor(Color(hex: "101828"))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Feature Row (Figma: icon 20×20, label-sm 14px #101828)

struct FeatureRow: View {
    let icon: String
    let text: String
    var iconColor: Color = Color(hex: "101828")
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(iconColor)
            
            Text(text)
                .font(.custom("Overused Grotesk", size: 14))
                .fontWeight(.regular)
                .foregroundColor(Color(hex: "101828"))
                .multilineTextAlignment(.leading)
            
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
                .foregroundColor(Color(hex: "101828"))
            
            HStack(spacing: 0) {
                Text(isCancelled ? "Access until: " : "Next payment: ")
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "6A7282"))
                
                Text(formatDate(nextPaymentDate))
                    .font(.custom("Overused Grotesk", size: 14))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "101828"))
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
