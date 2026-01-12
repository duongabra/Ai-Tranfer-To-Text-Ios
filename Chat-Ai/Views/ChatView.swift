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
        VStack(spacing: 0) {
            // MARK: - Messages List
            
            if viewModel.isLoading {
                // Đang load messages
                Spacer()
                ProgressView("Loading messages...")
                Spacer()
            } else if viewModel.messages.isEmpty {
                // Chưa có message nào
                emptyStateView
            } else {
                // Danh sách messages
                messagesListView
            }
            
            // MARK: - Transcription Progress
            
            // Hiển thị progress khi đang transcribe
            if viewModel.isTranscribing, let progress = viewModel.transcriptionProgress {
                transcriptionProgressBanner(message: progress)
            }
            
            // MARK: - Error Message
            
            // Hiển thị lỗi (nếu có)
            if let errorMessage = viewModel.errorMessage {
                errorBanner(message: errorMessage)
            }
            
            // MARK: - Input Area
            
            inputArea
        }
        .navigationTitle(viewModel.conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Menu với 3 options: Rename, Clear Chat và Delete Conversation
            ToolbarItem(placement: .navigationBarTrailing) {
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
                    Image(systemName: "ellipsis.circle")
                }
            }
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
        .task {
            // Load messages khi view xuất hiện
            await viewModel.loadMessages()
        }
    }
    
    // MARK: - Messages List View
    
    /// View hiển thị danh sách messages
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id) // ID để scroll đến message này
                    }
                    
                    // ✅ Typing indicator khi AI đang trả lời
                    if viewModel.isSending {
                        TypingIndicatorView()
                            .id("typing") // ID để scroll đến typing indicator
                    }
                }
                .padding()
            }
            // Tự động scroll xuống message mới nhất hoặc typing indicator
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isSending) { _, isSending in
                if isSending {
                    // Scroll đến typing indicator khi bắt đầu gửi
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State View
    
    /// View hiển thị khi chưa có message
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Start conversation")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Send your first message to chat with AI")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    // MARK: - Transcription Progress Banner
    
    /// Banner hiển thị progress khi đang transcribe
    private func transcriptionProgressBanner(message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.blue)
            
            Text(message)
                .font(.subheadline)
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
                .font(.caption)
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
    
    /// Vùng nhập tin nhắn
    private var inputArea: some View {
        VStack(spacing: 0) {
            // ✅ File preview (nếu có file được chọn)
            if let selectedFile = viewModel.selectedFile {
                filePreviewBanner(file: selectedFile)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // ✅ Nút attach file
                Menu {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label("Photo & Video", systemImage: "photo")
                    }
                    
                    Button(action: {
                        showingAudioPicker = true
                    }) {
                        Label("Audio", systemImage: "waveform")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                }
                .disabled(viewModel.isSending)
                
                // Text field để nhập message
                TextField("Type a message...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .lineLimit(1...5) // Tối đa 5 dòng
                    .disabled(viewModel.isSending) // Disable khi đang gửi
                
                // Nút gửi
                Button(action: {
                    Task {
                        // Nếu có file → Gửi file
                        if let selectedFile = viewModel.selectedFile,
                           let fileData = selectedFileData {
                            await viewModel.sendMessageWithFile(
                                data: fileData,
                                fileName: selectedFile.name,
                                fileType: selectedFile.type
                            )
                            selectedFileData = nil
                        } else {
                            // Không có file → Gửi text thường
                            await viewModel.sendMessage()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(canSendMessage ? Color.blue : Color.gray)
                            .frame(width: 40, height: 40)
                        
                        if viewModel.isSending {
                            // Hiển thị loading khi đang gửi
                            ProgressView()
                                .tint(.white)
                        } else {
                            // Icon gửi
                            Image(systemName: "arrow.up")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .disabled(!canSendMessage || viewModel.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
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
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(file.formattedSize)
                    .font(.caption)
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

// MARK: - Message Bubble

/// Bubble hiển thị một message
struct MessageBubble: View {
    let message: Message
    @State private var showCopiedFeedback = false
    
    var body: some View {
        HStack {
            // Nếu là message của user, đẩy sang phải
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                VStack(alignment: .leading, spacing: 8) {
                    // ✅ File attachment (nếu có)
                    if let attachment = message.attachment {
                        FileAttachmentView(attachment: attachment)
                    }
                    
                    // Nội dung message (nếu không phải chỉ có file)
                    if !message.content.isEmpty && message.content != "📎 Sent a file" {
                        Text(message.content)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(message.role == .user ? Color.blue : Color(.systemGray5))
                            .foregroundColor(message.role == .user ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
                
                // Thời gian và Copy button cùng hàng
                HStack {
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Copy button
                    Button(action: {
                        copyToClipboard(message.content)
                    }) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Nếu là message của AI, đẩy sang trái
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    /// Copy text to clipboard
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        
        // Show feedback
        showCopiedFeedback = true
        
        // Reset after 2 seconds
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

