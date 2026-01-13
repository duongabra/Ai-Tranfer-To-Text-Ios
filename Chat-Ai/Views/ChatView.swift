//
//  ChatView.swift
//  Chat-Ai
//
//  Màn hình chat với AI
//

import SwiftUI

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
    
    // Environment để dismiss view
    @Environment(\.dismiss) private var dismiss
    
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
    }
    
    // MARK: - Header
    
    /// Header theo design Figma
    private var chatHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.custom("Overused Grotesk", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
            }
            
            // Title ở giữa
            Text(viewModel.conversationTitle)
                .font(.custom("Overused Grotesk", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
        .padding(.top, 179) // Theo design Figma
        .padding(.bottom, 12)
    }
    
    // MARK: - Content Panel
    
    /// Content panel với video card và messages
    private var contentPanel: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Video uploaded card (nếu có video trong message đầu tiên của user)
                        if let firstUserMessage = viewModel.messages.first(where: { $0.role == .user }),
                           let attachment = firstUserMessage.attachment,
                           attachment.type == .video {
                            VideoUploadedCard(attachment: attachment)
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
                        } else if !viewModel.isLoading {
                            // Empty state
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100) // Space cho input area
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isSending) { _, isSending in
                    if isSending {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
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
                .frame(height: 64)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                HStack(spacing: 8) {
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 32)
            .background(Color.primaryOrange)
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
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: attachment.url)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 113, height: 64)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 113, height: 64)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.4))
                        )
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 113, height: 64)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // YouTube icon
                Image(systemName: "play.circle.fill")
                    .font(.custom("Overused Grotesk", size: 20))
                    .foregroundColor(.red)
                
                // Title và channel
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.name)
                        .font(.custom("Overused Grotesk", size: 13))
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                    
                    Text("Video")
                        .font(.custom("Overused Grotesk", size: 12))
                        .foregroundColor(.textTertiary)
                }
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
        .frame(width: 358)
    }
}

// MARK: - Message Bubble

/// Bubble hiển thị một message theo design Figma
struct MessageBubble: View {
    let message: Message
    let isFirstUserVideo: Bool
    @State private var showCopiedFeedback = false
    
    var body: some View {
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
                        .font(.custom("Overused Grotesk", size: 14))
                        .foregroundColor(.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 304, alignment: .leading)
            .padding(0)
        }
        .frame(maxWidth: 358, alignment: .leading)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView(conversation: Conversation(
            userId: UUID(),
            title: "Test Chat"
        ))
    }
}

