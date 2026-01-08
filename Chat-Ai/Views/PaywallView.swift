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
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Upgrade to Premium")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock unlimited messages and GPT-4 access")
                            .font(.subheadline)
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
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Features
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Premium Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "infinity", text: "Unlimited messages")
                        FeatureRow(icon: "brain.head.profile", text: "GPT-4 access")
                        FeatureRow(icon: "clock.arrow.circlepath", text: "Chat history saved forever")
                        FeatureRow(icon: "headphones", text: "Priority support")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
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
                    .padding(.horizontal)
                    
                    // MARK: - Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // MARK: - Restore Purchases
                    Button(action: {
                        restorePurchases()
                    }) {
                        Text("Restore Purchases")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                    
                    // MARK: - Terms
                    Text("Auto-renewable. Cancel anytime.")
                        .font(.caption)
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
        
        do {
            availablePlans = try await RevenueCatService.shared.getAvailablePlans()
            
            // Auto-select Monthly plan nếu có
            if let monthlyPlan = availablePlans.first(where: { $0.type == .monthly }) {
                selectedPlan = monthlyPlan
            } else if let firstPremiumPlan = availablePlans.first(where: { $0.isPremium }) {
                selectedPlan = firstPremiumPlan
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load plans: \(error.localizedDescription)"
            isLoading = false
            print("❌ Error loading plans: \(error)")
        }
    }
    
    // MARK: - Subscribe Action
    
    private func subscribeToPlan() {
        guard let selectedPlan = selectedPlan,
              let package = selectedPlan.package else {
            errorMessage = "Please select a plan"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Mua package
                _ = try await RevenueCatService.shared.purchase(package: package)
                
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
                            .font(.headline)
                        
                        if plan.type == .monthly {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(plan.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(plan.price)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(plan.duration)
                        .font(.caption)
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
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}

