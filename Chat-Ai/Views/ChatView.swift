//
//  ChatView.swift
//  Chat-Ai
//
//  Màn hình chat với AI
//

import SwiftUI
import AVFoundation

struct ChatView: View {
    
    let conversation: Conversation
    
    // StateObject: tạo ViewModel với conversation
    @StateObject private var viewModel: ChatViewModel
    
    // State để focus vào text field
    @FocusState private var isInputFocused: Bool
    
    // ✅ State cho file picker
    @State private var showingImagePicker = false
    @State private var showingAudioPicker = false
    @State private var selectedFileData: Data?
    
    // State để hiển thị confirmation dialog xóa chat
    @State private var showingClearChatConfirmation = false
    
    // State để hiển thị confirmation dialog xóa conversation
    @State private var showingDeleteConversationConfirmation = false
    
    // State để hiển thị rename sheet
    @State private var showingRenameSheet = false
    
    // Conversation list drawer state
    @State private var showingConversationListDrawer = false
    
    // Settings state
    @State private var showingSettings = false
    
    // State để lưu ScrollViewReader proxy
    @State private var scrollProxy: ScrollViewProxy?
    
    // State để track xem có đang ở bottom không
    @State private var isAtBottom = true
    
    // Environment để dismiss view
    @Environment(\.dismiss) private var dismiss
    
    // Environment object cho auth
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Environment object cho navigation coordinator
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    /// Initializer
    init(conversation: Conversation) {
        self.conversation = conversation
        // Khởi tạo ViewModel với conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }
    
    var body: some View {
        ZStack {
            // Background màu #FFF9F2
            Color.backgroundCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                chatHeader
                
                // MARK: - Content Panel
                contentPanel
                
                // MARK: - Input Area
                inputArea
            }
        }
        .navigationBarHidden(true)
        .task {
            // Load messages khi view xuất hiện
            await viewModel.loadMessages()
        }
        // Confirmation dialog: Clear Messages
        .confirmationDialog("Delete all messages?", isPresented: $showingClearChatConfirmation, titleVisibility: .visible) {
            Button("Delete Messages", role: .destructive) {
                Task {
                    await viewModel.clearAllMessages()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete all messages but keep the conversation.")
        }
        // Confirmation dialog: Delete Conversation
        .confirmationDialog("Delete conversation?", isPresented: $showingDeleteConversationConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteConversation()
                    dismiss() // Quay về list
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. The conversation and all messages will be permanently deleted.")
        }
        // Sheet: Rename Conversation
        .sheet(isPresented: $showingRenameSheet) {
            RenameConversationSheet(viewModel: viewModel)
        }
        // Conversation List Drawer overlay
        .overlay(alignment: .leading) {
            ConversationListDrawer(
                isPresented: $showingConversationListDrawer,
                navigationCoordinator: navigationCoordinator,
                onConversationSelected: { selectedConversation in
                    // Nếu chọn conversation khác, dismiss ChatView trước, sau đó navigate đến conversation mới
                    if selectedConversation.id != conversation.id {
                        print("🔄 ChatView: Selected conversation \(selectedConversation.title), current: \(conversation.title)")
                        // Đóng drawer trước
                        showingConversationListDrawer = false
                        // Dismiss ChatView trước
                        dismiss()
                        // Đợi một chút để ChatView dismiss xong, sau đó navigate đến conversation mới
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.navigationCoordinator.replaceConversation(selectedConversation)
                            print("🔄 ChatView: Navigated to conversation via coordinator")
                        }
                    }
                },
                onHomeSelected: {
                    // Sử dụng navigationCoordinator để về home
                    navigationCoordinator.navigateToHome()
                    // Dismiss ChatView
                    dismiss()
                },
                onSettingsSelected: {
                    showingSettings = true
                }
            )
            .environmentObject(authViewModel)
        }
        .overlay(alignment: .bottom) {
            if showingSettings {
                SettingsView()
                    .environmentObject(authViewModel)
                    .environmentObject(navigationCoordinator)
                    .transition(.move(edge: .bottom))
                    .zIndex(1000)
            }
        }
    }
    
    // MARK: - Header
    
    /// Header theo design Figma
    private var chatHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            // Menu icon (3 gạch ngang) để mở drawer
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingConversationListDrawer = true
                }
            }) {
                MenuIcon()
                    .frame(width: 40, height: 40)
            }
            
            // Title ở giữa
            Text("Summary Video")
                .font(.custom("Overused Grotesk", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            // Pro button với menu
            Menu {
                // Rename Conversation
                Button(action: {
                    showingRenameSheet = true
                }) {
                    Label("Rename", systemImage: "pencil")
                }
                
                Divider()
                
                // Clear Chat - Xóa messages, giữ conversation
                if !viewModel.messages.isEmpty {
                    Button(role: .destructive, action: {
                        showingClearChatConfirmation = true
                    }) {
                        Label("Clear Messages", systemImage: "eraser")
                    }
                }
                
                // Delete Conversation - Xóa luôn conversation
                Button(role: .destructive, action: {
                    showingDeleteConversationConfirmation = true
                }) {
                    Label("Delete Conversation", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Pro")
                        .font(.custom("Overused Grotesk", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.textWhite)
                    
                    Image(systemName: "crown.fill")
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(.textWhite)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primaryOrange)
                .overlay(
                    RoundedRectangle(cornerRadius: 9999)
                        .stroke(Color.primaryOrange.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(9999)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 0) // Giảm padding top để giảm khoảng trống
        .padding(.bottom, 12)
    }
    
    // MARK: - Content Panel
    
    /// Content panel với video card và messages
    private var contentPanel: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Video uploaded card (nếu có video trong message đầu tiên của user)
                        if let firstUserMessage = viewModel.messages.first(where: { $0.role == .user }),
                           let attachment = firstUserMessage.attachment,
                           attachment.type == .video {
                            VideoUploadedCard(attachment: attachment)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 0) // Padding đã được xử lý trong GeometryReader
                        }
                        
                        // Loading indicator
                        if viewModel.isLoading {
                            ProgressView("Loading messages...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                        }
                        
                        // Messages list
                        if !viewModel.messages.isEmpty {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFirstUserVideo: isFirstUserVideoMessage(message)
                                )
                                .id(message.id)
                            }
                            
                            // Typing indicator
                            if viewModel.isSending {
                                TypingIndicatorView()
                                    .id("typing")
                            }
                            
                            // Bottom marker để detect khi scroll đến bottom
                            Color.clear
                                .frame(height: 1)
                                .id("bottom-marker")
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .preference(key: BottomMarkerPreferenceKey.self, value: geometry.frame(in: .named("scrollView")).minY)
                                    }
                                )
                                .onAppear {
                                    // Khi marker xuất hiện, nghĩa là đã ở bottom
                                    isAtBottom = true
                                }
                                .onDisappear {
                                    // Khi marker biến mất, nghĩa là đã scroll lên
                                    isAtBottom = false
                                }
                        } else if !viewModel.isLoading {
                            // Empty state
                            emptyStateView
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 12) // Padding top hợp lý
                    .padding(.bottom, 12) // Padding bottom hợp lý
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(BottomMarkerPreferenceKey.self) { value in
                    // Update liên tục khi scroll để detect chính xác hơn
                    handleScrollPositionChange(value)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        // Reset isAtBottom khi có message mới
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isAtBottom = true
                        }
                    }
                }
                .onChange(of: viewModel.isSending) { _, isSending in
                    if isSending {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isAtBottom = true
                        }
                    }
                }
                .background(
                    // Store proxy để dùng trong button
                    Color.clear
                        .onAppear {
                            scrollProxy = proxy
                        }
                )
            }
            
            // Gradient mask ở cuối
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.backgroundCream.opacity(0),
                        Color.backgroundCream
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)
            }
            
            // Down arrow button để scroll xuống message cuối cùng - chỉ hiển thị khi không ở bottom
            if !viewModel.messages.isEmpty && !isAtBottom {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            scrollToBottom()
                        }) {
                            Image("down_arrow_icon")
                                .resizable()
                                .renderingMode(.original)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                )
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8) // Padding để không che input area
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Function để scroll xuống message cuối cùng
    private func scrollToBottom() {
        if let lastMessage = viewModel.messages.last {
            withAnimation {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else if viewModel.isSending {
            withAnimation {
                scrollProxy?.scrollTo("typing", anchor: .bottom)
            }
        }
        // Set isAtBottom sau khi scroll
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAtBottom = true
        }
    }
    
    // Function để handle scroll position change
    private func handleScrollPositionChange(_ value: CGFloat) {
        // Khi marker ở trong viewport (value nhỏ và dương), nghĩa là đã ở bottom
        // value sẽ là khoảng cách từ top của scroll view đến marker
        // Nếu value < một threshold, nghĩa là marker đã visible (ở bottom)
        let screenHeight = UIScreen.main.bounds.height
        let threshold: CGFloat = screenHeight * 0.8 // Threshold để xác định "ở bottom" (80% screen height)
        // Nếu marker ở gần bottom của screen (value nhỏ hơn threshold), nghĩa là đã ở bottom
        isAtBottom = value < threshold && value > -screenHeight
    }
    
    /// Kiểm tra xem message có phải là video đầu tiên của user không
    private func isFirstUserVideoMessage(_ message: Message) -> Bool {
        guard message.role == .user,
              let attachment = message.attachment,
              attachment.type == .video else {
            return false
        }
        
        // Tìm message đầu tiên của user có video
        if let firstUserVideoMessage = viewModel.messages.first(where: { msg in
            msg.role == .user && msg.attachment?.type == .video
        }) {
            return message.id == firstUserVideoMessage.id
        }
        
        return false
    }
    // MARK: - Empty State View
    
    /// View hiển thị khi chưa có message
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "message")
                .font(.custom("Overused Grotesk", size: 60))
                .foregroundColor(.textTertiary)
            
            Text("Start conversation")
                .font(.custom("Overused Grotesk", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            Text("Send your first message to chat with AI")
                .font(.custom("Overused Grotesk", size: 14))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Transcription Progress Banner
    
    /// Banner hiển thị progress khi đang transcribe
    private func transcriptionProgressBanner(message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.blue)
            
            Text(message)
                .font(.custom("Overused Grotesk", size: 15))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Error Banner
    
    /// Banner hiển thị lỗi
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.custom("Overused Grotesk", size: 12))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                viewModel.errorMessage = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
    
    // MARK: - Input Area
    
    /// Vùng nhập tin nhắn theo design Figma
    private var inputArea: some View {
        VStack(spacing: 0) {
            // File preview (nếu có file được chọn)
            if let selectedFile = viewModel.selectedFile {
                filePreviewBanner(file: selectedFile)
            }
            
            // Input container với background màu cam
            HStack(alignment: .bottom, spacing: 8) {
                // Input field
                TextField("Ask anything about video ...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.custom("Overused Grotesk", size: 14))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: "F4F4F4"), lineWidth: 1)
                    )
                    .cornerRadius(24)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .disabled(viewModel.isSending)
                
                // Send button
                Button(action: {
                    Task {
                        if let selectedFile = viewModel.selectedFile,
                           let fileData = selectedFileData {
                            await viewModel.sendMessageWithFile(
                                data: fileData,
                                fileName: selectedFile.name,
                                fileType: selectedFile.type
                            )
                            selectedFileData = nil
                        } else {
                            await viewModel.sendMessage()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(canSendMessage ? Color.primaryOrange : Color.primaryOrange.opacity(0.4))
                            .frame(width: 32, height: 32)
                        
                        if viewModel.isSending {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.custom("Overused Grotesk", size: 14))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!canSendMessage || viewModel.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 0)
            .background(Color.backgroundCream) // Đổi từ cam sang cream
        }
        .sheet(isPresented: $showingImagePicker) {
            FilePicker(
                selectedFile: $viewModel.selectedFile,
                selectedData: $selectedFileData,
                fileTypes: [.image, .video]
            )
        }
        .sheet(isPresented: $showingAudioPicker) {
            AudioPicker(
                selectedFile: $viewModel.selectedFile,
                selectedData: $selectedFileData
            )
        }
    }
    
    // ✅ Helper: Kiểm tra có thể gửi message không
    private var canSendMessage: Bool {
        // Có file hoặc có text
        return viewModel.selectedFile != nil || !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // ✅ File preview banner
    private func filePreviewBanner(file: FileAttachment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.type.icon)
                .font(.custom("Overused Grotesk", size: 22))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.custom("Overused Grotesk", size: 15))
                    .lineLimit(1)
                
                Text(file.formattedSize)
                    .font(.custom("Overused Grotesk", size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.cancelFileSelection()
                selectedFileData = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
}

// MARK: - Video Uploaded Card

/// Card hiển thị video đã upload theo design Figma
struct VideoUploadedCard: View {
    let attachment: FileAttachment
    
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 16
        let cardMaxWidth = screenWidth - (horizontalPadding * 2)
        let thumbnailWidth = min(113, cardMaxWidth * 0.3) // 30% của card width, max 113
        let thumbnailHeight = thumbnailWidth * (64.0 / 113.0) // Giữ tỷ lệ 113:64
        
        HStack(alignment: .center, spacing: 8) {
            // Thumbnail
            Group {
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                }
            }
            .onAppear {
                extractVideoThumbnail(from: attachment.url)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.custom("Overused Grotesk", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Text("Video")
                    .font(.custom("Overused Grotesk", size: 12))
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "F4F4F4"), lineWidth: 1)
        )
        .cornerRadius(16)
        .frame(maxWidth: cardMaxWidth)
    }
    
    // MARK: - Extract Video Thumbnail
    
    private func extractVideoThumbnail(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid video URL: \(urlString)")
            return
        }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    videoThumbnail = uiImage
                }
            } catch {
                print("❌ Failed to extract video thumbnail: \(error)")
                await MainActor.run {
                    videoThumbnail = nil
                }
            }
        }
    }
}

// MARK: - Message Bubble

/// Bubble hiển thị một message theo design Figma
struct MessageBubble: View {
    let message: Message
    let isFirstUserVideo: Bool
    @State private var showCopiedFeedback = false
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 16
        let contentMaxWidth = screenWidth - (horizontalPadding * 2)
        let botMessageMaxWidth = min(304, contentMaxWidth * 0.85) // 85% của content width, max 304
        let userMessageMaxWidth = min(320, contentMaxWidth * 0.9) // 90% của content width, max 320
        
        if message.role == .assistant {
            // Assistant message: align về trái, không có background
            HStack {
                VStack(alignment: .leading, spacing: 16) {
                    // Message content container
                    VStack(alignment: .leading, spacing: 8) {
                        // File attachment (nếu có)
                        if let attachment = message.attachment {
                            // Chỉ hiển thị file attachment nếu không phải video đầu tiên của user (đã hiển thị ở card riêng)
                            if !isFirstUserVideo {
                                FileAttachmentView(attachment: attachment)
                            }
                        }
                        
                        // Nội dung message
                        if !message.content.isEmpty && message.content != "📎 Sent a file" {
                            Text(message.content)
                                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                                .monospacedDigit() // font-variant-numeric: lining-nums tabular-nums
                                .foregroundColor(Color(hex: "020202")) // color: #020202
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(6) // Line height 20px = 14px font + 6px spacing
                        }
                    }
                    .frame(maxWidth: botMessageMaxWidth, alignment: .leading)
                    
                    // Actions icon (copy) - chỉ hiển thị cho assistant messages
                    HStack(spacing: 8) {
                        Button(action: {
                            copyToClipboard(message.content)
                        }) {
                            Image("copy_icon")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.textTertiary)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                
                Spacer()
            }
        } else {
            // User message: align về phải, có background white + border
            // Fit content khi ngắn, max width khi dài
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    // Message content container
                    VStack(alignment: .trailing, spacing: 8) {
                        // File attachment (nếu có)
                        if let attachment = message.attachment {
                            // Chỉ hiển thị file attachment nếu không phải video đầu tiên của user (đã hiển thị ở card riêng)
                            if !isFirstUserVideo {
                                FileAttachmentView(attachment: attachment)
                            }
                        }
                        
                        // Nội dung message
                        if !message.content.isEmpty && message.content != "📎 Sent a file" {
                            Text(message.content)
                                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                                .monospacedDigit() // font-variant-numeric: lining-nums tabular-nums
                                .foregroundColor(Color(hex: "020202")) // color: #020202
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(6) // Line height 20px = 14px font + 6px spacing
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "F4F4F4"), lineWidth: 1)
                )
                .cornerRadius(16)
                .frame(maxWidth: userMessageMaxWidth, alignment: .trailing) // Max width khi dài, fit content khi ngắn
        }
        }
    }
    
    /// Copy text to clipboard
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedFeedback = false
        }
    }
    
    /// Format time thành string
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Rename Conversation Sheet

/// Sheet để đổi tên conversation
struct RenameConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var newTitle: String
    
    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        // ✅ Dùng conversationTitle (mới) thay vì conversation.title (cũ)
        _newTitle = State(initialValue: viewModel.conversationTitle)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Conversation name", text: $newTitle)
                } header: {
                    Text("Rename")
                } footer: {
                    Text("Enter a new name for this conversation.")
                }
            }
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Nút Cancel
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Nút Save
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.renameConversation(newTitle: newTitle)
                            dismiss()
                        }
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preference Keys for Scroll Detection

struct BottomMarkerPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView(conversation: Conversation(
            userId: UUID(),
            title: "Test Chat"
        ))
    }
}

