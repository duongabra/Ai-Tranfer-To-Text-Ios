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
                ProgressView("Đang tải tin nhắn...")
                Spacer()
            } else if viewModel.messages.isEmpty {
                // Chưa có message nào
                emptyStateView
            } else {
                // Danh sách messages
                messagesListView
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
        .confirmationDialog("Xóa tất cả tin nhắn?", isPresented: $showingClearChatConfirmation, titleVisibility: .visible) {
            Button("Xóa tin nhắn", role: .destructive) {
                Task {
                    await viewModel.clearAllMessages()
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Xóa tất cả tin nhắn nhưng giữ lại cuộc hội thoại.")
        }
        // Confirmation dialog: Delete Conversation
        .confirmationDialog("Xóa cuộc hội thoại?", isPresented: $showingDeleteConversationConfirmation, titleVisibility: .visible) {
            Button("Xóa", role: .destructive) {
                Task {
                    await viewModel.deleteConversation()
                    dismiss() // Quay về list
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Hành động này không thể hoàn tác. Cuộc hội thoại và tất cả tin nhắn sẽ bị xóa vĩnh viễn.")
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
            
            Text("Bắt đầu cuộc hội thoại")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Gửi tin nhắn đầu tiên để chat với AI")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
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
                TextField("Nhập tin nhắn...", text: $viewModel.inputText, axis: .vertical)
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
            .padding(.horizontal)
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
    
    var body: some View {
        HStack {
            // Nếu là message của user, đẩy sang phải
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    // ✅ File attachment (nếu có)
                    if let attachment = message.attachment {
                        FileAttachmentView(attachment: attachment)
                    }
                    
                    // Nội dung message (nếu không phải chỉ có file)
                    if !message.content.isEmpty && message.content != "📎 Sent a file" {
                        Text(message.content)
                            .padding(12)
                            .background(message.role == .user ? Color.blue : Color(.systemGray5))
                            .foregroundColor(message.role == .user ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
                
                // Thời gian
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Nếu là message của AI, đẩy sang trái
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
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
                    TextField("Tên cuộc hội thoại", text: $newTitle)
                } header: {
                    Text("Đổi tên")
                } footer: {
                    Text("Nhập tên mới cho cuộc hội thoại này.")
                }
            }
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Nút Cancel
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                
                // Nút Save
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
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

