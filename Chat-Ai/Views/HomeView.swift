//
//  HomeView.swift
//  Chat-Ai
//
//  Màn hình Home sau khi login
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    @State private var hasActiveSubscription = false
    @State private var isLoadingSubscription = true
    
    // File picker states
    @State private var showingUploadModal = false
    @State private var showingImageVideoPicker = false
    @State private var showingAudioPicker = false
    @State private var selectedFile: FileAttachment?
    @State private var selectedFileData: Data?
    
    // Conversation list drawer state
    @State private var showingConversationListDrawer = false
    
    // Settings state
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.navigationPath) {
            ZStack(alignment: .bottom) {
            // Background - màu trắng #FFF
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                homeHeader
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Placeholder image (sẽ thêm ảnh sau)
                        ImagePlaceholder
                        
                        // Title Section
                        titleSection
                        
                        // Action Cards
                        actionCardsSection
                        
                        // Spacer để tạo khoảng trống cho graphic
                        Spacer()
                            .frame(height: 300)
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, 0)
                }
            }
            
            // Graphic decoration ở cuối màn hình (fixed position)
            VStack {
                Spacer()
                HomeGraphicView()
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
            }
            .task {
                await checkSubscriptionStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh subscription status khi app quay lại foreground
                Task {
                    await checkSubscriptionStatus()
                }
            }
            .navigationDestination(for: PaywallDestination.self) { _ in
                PaywallView()
                    .onDisappear {
                        // Refresh subscription status sau khi đóng PaywallView
                        // Thêm delay nhỏ để RevenueCat sync lại customer info
                        Task {
                            // Đợi 500ms để RevenueCat sync lại data
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await checkSubscriptionStatus()
                        }
                    }
            }
            .overlay(alignment: .bottom) {
                // Upload File Modal
                if showingUploadModal {
                    UploadFileModal(
                        isPresented: $showingUploadModal,
                        selectedFile: $selectedFile,
                        selectedFileData: $selectedFileData,
                        onTranscribeSuccess: { conversation in
                            // Navigate đến ChatView với conversation mới
                            navigationCoordinator.navigateToConversation(conversation)
                        }
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(1000)
                }
            }
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(conversation: conversation)
                    .environmentObject(navigationCoordinator)
            }
            .overlay(alignment: .leading) {
                // Conversation List Drawer
                ConversationListDrawer(
                    isPresented: $showingConversationListDrawer,
                    navigationCoordinator: navigationCoordinator,
                    onConversationSelected: { conversation in
                        navigationCoordinator.navigateToConversation(conversation)
                    },
                    onHomeSelected: {
                        navigationCoordinator.navigateToHome()
                    },
                    onSettingsSelected: {
                        showingSettings = true
                    }
                )
            }
            .environmentObject(navigationCoordinator)
            .overlay(alignment: .bottom) {
                if showingSettings {
                    SettingsView(isPresented: $showingSettings)
                        .environmentObject(authViewModel)
                        .environmentObject(navigationCoordinator)
                        .transition(.move(edge: .bottom))
                        .zIndex(1000)
                }
            }
        }
        .sheet(isPresented: $showingImageVideoPicker) {
            FilePicker(
                selectedFile: $selectedFile,
                selectedData: $selectedFileData,
                fileTypes: [.image, .video]
            )
            .onDisappear {
                // Xử lý file sau khi chọn
                if let file = selectedFile, let data = selectedFileData {
                    handleFileSelected(file: file, data: data)
                }
            }
        }
        .sheet(isPresented: $showingAudioPicker) {
            AudioPicker(
                selectedFile: $selectedFile,
                selectedData: $selectedFileData
            )
            .onDisappear {
                // Xử lý file sau khi chọn
                if let file = selectedFile, let data = selectedFileData {
                    handleFileSelected(file: file, data: data)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var homeHeader: some View {
        HStack {
            // Menu icon (3 gạch ngang)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingConversationListDrawer = true
                }
            }) {
                MenuIcon()
                    .frame(width: 40, height: 40)
            }
            
            Spacer()
            
            // Subscription Badge - Clickable
            Button(action: {
                navigationCoordinator.navigationPath.append(PaywallDestination())
            }) {
                SubscriptionBadge(isPro: hasActiveSubscription)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Image Placeholder
    
    private var ImagePlaceholder: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Welcome to VidSum")
                .font(.headingLarge)
                .lineSpacing(36 - 28) // line-height 36px - font-size 28px = 8px
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Upload a video or audio file, or paste a YouTube/X link to get started")
                .font(.bodyMedium)
                .lineSpacing(19.6 - 14) // line-height 19.6px - font-size 14px = 5.6px
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Action Cards Section
    
    private var actionCardsSection: some View {
        HStack(spacing: 16) {
            // Upload File Card
            ActionCard(
                icon: "upload_3_line",
                title: "Upload File",
                subtitle: "Upload Audio or Video",
                backgroundColor: Color.primaryOrange.opacity(0.1),
                iconColor: .primaryOrange
            ) {
                // Hiển thị modal upload file
                showingUploadModal = true
            }
            
            // Paste Link Card
            ActionCard(
                icon: "link_2_line",
                title: "Paste Link",
                subtitle: "YouTube or X video URL",
                backgroundColor: Color(hex: "FF920A").opacity(0.1),
                iconColor: Color(hex: "FF920A")
            ) {
                // TODO: Handle paste link
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Methods
    
    private func checkSubscriptionStatus() async {
        isLoadingSubscription = true
        
        // TẠM THỜI: Check subscription từ StoreKit 2
        let currentProductId = await StoreKitService.shared.getCurrentSubscriptionProductId()
        hasActiveSubscription = (currentProductId != nil)
        
        isLoadingSubscription = false
    }
    
    // MARK: - Handle File Selected
    
    private func handleFileSelected(file: FileAttachment, data: Data) {
        
        // TODO: Xử lý file đã chọn
        // Có thể:
        // 1. Navigate đến ChatView với file đã chọn
        // 2. Upload file lên server
        // 3. Hiển thị preview và xử lý
        
        // Reset sau khi xử lý
        selectedFile = nil
        selectedFileData = nil
    }
}

// MARK: - Subscription Badge

struct SubscriptionBadge: View {
    let isPro: Bool
    
    var body: some View {
        if isPro {
            // Pro Badge - Crown trắng trên nền cam
            HStack(spacing: 4) {
                Text("Pro")
                    .font(.labelMedium)
                    .foregroundColor(.white)
                
                Image("VIP_2_fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primaryOrange)
            .cornerRadius(9999)
        } else {
            // Upgrade Badge - Crown cam trên nền trắng
            HStack(spacing: 4) {
                Text("Upgrade")
                    .font(.labelMedium)
                    .foregroundColor(.primaryOrange)
                
                Image(systemName: "crown.fill")
                    .font(.custom("Overused Grotesk", size: 14))
                    .foregroundColor(.primaryOrange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primaryOrange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 9999)
                    .stroke(Color.primaryOrange.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(9999)
        }
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon - sử dụng ảnh từ Assets
                if icon == "upload_3_line" {
                    Image("upload")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                } else if icon == "link_2_line" {
                    Image("paste_link")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "doc")
                        .font(.custom("Overused Grotesk", size: 24))
                        .foregroundColor(iconColor)
                        .frame(width: 48, height: 48)
                        .background(iconColor.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Text
                VStack(spacing: 4) {
                    Text(title)
                        .font(.labelLarge)
                        .lineSpacing(28 - 18) // line-height 28px - font-size 18px = 10px
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.custom("Overused Grotesk", size: 13))
                        .fontWeight(.regular)
                        .lineSpacing(3) // line-height 16px - font-size 13px = 3px
                        .foregroundColor(Color(red: 113/255, green: 113/255, blue: 113/255))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .textCase(nil)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}

