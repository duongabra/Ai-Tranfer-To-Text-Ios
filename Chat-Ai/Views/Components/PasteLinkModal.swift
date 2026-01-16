//
//  PasteLinkModal.swift
//  Chat-Ai
//
//  Modal để paste video URL (YouTube/X)
//

import SwiftUI
import UIKit
import Foundation

enum PasteLinkStatus: Equatable {
    case idle           // Chưa có URL
    case typing          // Đang nhập URL
    case hasValue        // Có URL hợp lệ
    case error(String)   // URL không hợp lệ
    case loading         // Đang xử lý
}

struct PasteLinkModal: View {
    @Binding var isPresented: Bool
    
    // Callback khi transcribe thành công và tạo conversation xong
    var onTranscribeSuccess: ((Conversation) -> Void)?
    
    @State private var linkText: String = ""
    @State private var status: PasteLinkStatus = .idle
    @State private var isLoading = false
    
    var body: some View {
        if isPresented {
            modalContent
                .onAppear {
                    resetState()
                }
        } else {
            Color.clear
                .onAppear {
                    resetState()
                }
        }
    }
    
    // MARK: - Modal Content
    
    private var modalContent: some View {
        ZStack(alignment: .bottom) {
            backgroundBlur
            modalBody
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
    
    private var backgroundBlur: some View {
        Color.white.opacity(0.3)
            .ignoresSafeArea(edges: .all)
            .background(.ultraThinMaterial)
            .onTapGesture {
                // Không làm gì - chặn tap để đóng modal
            }
    }
    
    private var modalBody: some View {
        VStack(spacing: 0) {
            headerView
            contentView
        }
        .background(Color(hex: "FAFAFA"))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 32, x: 0, y: 0)
        .transition(.move(edge: .bottom))
    }
    
    private var headerView: some View {
        HStack {
            // Close button (left) - invisible placeholder để căn giữa title
            Button(action: {
                if !isLoading {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.custom("Overused Grotesk", size: 16))
                    .foregroundColor(.clear)
                    .frame(width: 28, height: 28)
            }
            .opacity(0)
            
            Spacer()
            
            // Title
            Text("Paste Link")
                .font(.labelMedium)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            // Close button (right) - ẩn khi đang loading
            if !isLoading {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.custom("Overused Grotesk", size: 16))
                        .foregroundColor(.textPrimary)
                        .frame(width: 28, height: 28)
                }
            } else {
                // Placeholder để giữ layout khi ẩn button
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private var contentView: some View {
        VStack(spacing: 12) {
            // Input field
            inputField
            
            // Next button
            nextButton
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    
    private var inputField: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TextField("Paste a YouTube/X URL…", text: $linkText)
                    .font(.custom("Overused Grotesk", size: 14))
                    .foregroundColor(.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .onChange(of: linkText) { newValue in
                        validateURL(newValue)
                    }
                
                // Clear button (hiển thị khi có text và không phải error state)
                if !linkText.isEmpty && !isErrorState {
                    Button(action: {
                        linkText = ""
                        status = .idle
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.textTertiary)
                    }
                }
                
                // Error icon (hiển thị khi error state)
                if isErrorState {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(16)
            
            // Error message
            if case .error(let message) = status {
                Text(message)
                    .font(.custom("Overused Grotesk", size: 12))
                    .foregroundColor(.red)
                    .padding(.top, 4)
                    .padding(.leading, 12)
            }
        }
    }
    
    private var borderColor: Color {
        switch status {
        case .error:
            return .red
        case .hasValue, .typing:
            return Color.primaryOrange
        default:
            return Color(hex: "E4E4E4")
        }
    }
    
    private var isErrorState: Bool {
        if case .error = status {
            return true
        }
        return false
    }
    
    private var nextButton: some View {
        Button(action: {
            handleNext()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .textWhite))
                } else {
                    Text("Next")
                        .font(.custom("Overused Grotesk", size: 16))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(buttonBackgroundColor)
            .foregroundColor(buttonTextColor)
            .cornerRadius(16)
        }
        .disabled(!isButtonEnabled || isLoading)
    }
    
    private var buttonBackgroundColor: Color {
        if isButtonEnabled && !isLoading {
            return Color.primaryOrange
        }
        return Color.primaryOrange.opacity(0.4)
    }
    
    private var buttonTextColor: Color {
        if isButtonEnabled && !isLoading {
            return .textWhite
        }
        return Color(hex: "FAFAFA")
    }
    
    private var isButtonEnabled: Bool {
        if case .hasValue = status {
            return true
        }
        return false
    }
    
    // MARK: - Validation
    
    private func validateURL(_ urlString: String) {
        if urlString.isEmpty {
            status = .idle
            return
        }
        
        // Set typing status khi đang nhập
        status = .typing
        
        // Kiểm tra URL có hợp lệ không
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            // Chỉ set error nếu đã nhập đủ ký tự (tránh error khi đang gõ)
            if urlString.count > 10 {
                status = .error("Invalid URL format")
            }
            return
        }
        
        // Chỉ chấp nhận YouTube hoặc X (Twitter) video URL
        let isValidYouTube = host.contains("youtube.com") || host.contains("youtu.be")
        let isValidX = host.contains("x.com") || host.contains("twitter.com")
        
        if isValidYouTube || isValidX {
            // Kiểm tra xem có phải video URL không (không phải audio)
            if isValidYouTube {
                // YouTube: kiểm tra có video ID trong URL
                if urlString.contains("/watch?v=") || urlString.contains("youtu.be/") {
                    status = .hasValue
                } else {
                    // Chỉ set error nếu đã nhập đủ ký tự
                    if urlString.count > 20 {
                        status = .error("Please enter a valid YouTube video URL")
                    }
                }
            } else if isValidX {
                // X/Twitter: kiểm tra có status ID trong URL
                if urlString.contains("/status/") || urlString.contains("/i/status/") {
                    status = .hasValue
                } else {
                    // Chỉ set error nếu đã nhập đủ ký tự
                    if urlString.count > 20 {
                        status = .error("Please enter a valid X/Twitter video URL")
                    }
                }
            }
        } else {
            // Chỉ set error nếu đã nhập đủ ký tự
            if urlString.count > 10 {
                status = .error("Only YouTube or X video URLs are supported")
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleNext() {
        guard case .hasValue = status else { return }
        
        isLoading = true
        
        Task {
            do {
                // Gọi API transcribe video URL
                let userId = 8042467986 // Fixed user_id for transcribe API
                let result = try await TranscribeService.shared.transcribeVideoURL(
                    videoURL: linkText,
                    userId: userId
                )
                
                print("🔗 [PasteLinkModal] Transcription result:")
                print("   - Transcription URL (S3): \(result.transcriptionURL)")
                print("   - Message text length: \(result.message.count) characters")
                
                // Tạo conversation mới với title từ URL
                let conversationTitle = extractTitleFromURL(linkText)
                let newConversation = try await SupabaseService.shared.createConversation(title: conversationTitle)
                
                // Tạo user message với video URL
                let userMessage = try await SupabaseService.shared.createMessage(
                    conversationId: newConversation.id,
                    role: .user,
                    content: linkText,
                    fileUrl: linkText,
                    fileName: "video_url",
                    fileType: "video",
                    fileSize: nil
                )
                
                print("🔗 [PasteLinkModal] User message created: \(userMessage.id)")
                
                // Tạo assistant message với transcription
                let transcriptionFileName = "transcript_\(Date().timeIntervalSince1970).txt"
                let transcriptionMessage = try await SupabaseService.shared.createMessage(
                    conversationId: newConversation.id,
                    role: .assistant,
                    content: result.message,
                    fileUrl: result.transcriptionURL,
                    fileName: transcriptionFileName,
                    fileType: "other",
                    fileSize: nil
                )
                
                print("🔗 [PasteLinkModal] Transcription message created: \(transcriptionMessage.id)")
                
                // Update conversation timestamp
                try await SupabaseService.shared.updateConversationTimestamp(conversationId: newConversation.id)
                
                await MainActor.run {
                    isLoading = false
                    isPresented = false
                    onTranscribeSuccess?(newConversation)
                }
                
            } catch {
                print("❌ [PasteLinkModal] Error: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    status = .error("Failed to process video: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func extractTitleFromURL(_ urlString: String) -> String {
        // Extract video ID từ URL để làm title
        if let url = URL(string: urlString) {
            if urlString.contains("youtube.com/watch?v=") {
                if let videoID = url.queryItems?.first(where: { $0.name == "v" })?.value {
                    return "YouTube Video \(videoID.prefix(8))"
                }
            } else if urlString.contains("youtu.be/") {
                let pathComponents = url.pathComponents
                if let videoID = pathComponents.last, !videoID.isEmpty {
                    return "YouTube Video \(videoID.prefix(8))"
                }
            } else if urlString.contains("/status/") || urlString.contains("/i/status/") {
                let pathComponents = url.pathComponents
                if let statusIndex = pathComponents.firstIndex(where: { $0 == "status" || $0 == "i" }),
                   statusIndex + 1 < pathComponents.count {
                    let statusID = pathComponents[statusIndex + 1]
                    return "X Video \(statusID.prefix(8))"
                }
            }
        }
        
        // Fallback: dùng domain name
        if let url = URL(string: urlString), let host = url.host {
            return "Video from \(host)"
        }
        
        return "Video Link"
    }
    
    private func resetState() {
        linkText = ""
        status = .idle
        isLoading = false
    }
}

// MARK: - URL Extension

extension URL {
    var queryItems: [URLQueryItem]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems
    }
}

// MARK: - Preview

#Preview {
    PasteLinkModal(
        isPresented: .constant(true),
        onTranscribeSuccess: { conversation in
            print("Conversation created: \(conversation.id)")
        }
    )
}
