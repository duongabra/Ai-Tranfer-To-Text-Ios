//
//  UploadFileModal.swift
//  Chat-Ai
//
//  Modal để upload file (ảnh/video/audio)
//

import SwiftUI
import UIKit
import AVKit
import AVFoundation

// MARK: - Upload Status

enum UploadStatus: Equatable {
    case idle           // Chưa chọn file
    case preview        // Đã chọn file hợp lệ, hiển thị preview (chưa upload)
    case loading        // Đang upload
    case success        // Upload thành công
    case failed(String) // Upload thất bại với error message
}

struct UploadFileModal: View {
    @Binding var isPresented: Bool
    @Binding var selectedFile: FileAttachment?
    @Binding var selectedFileData: Data?
    
    // Callback khi transcribe thành công và tạo conversation xong
    var onTranscribeSuccess: ((Conversation) -> Void)?
    
    @State private var showingUnifiedPicker = false
    @State private var uploadStatus: UploadStatus = .idle
    @State private var uploadedFileURL: String? = nil
    @State private var toastMessage: String? = nil
    
    // Giới hạn file size: 300MB
    private let maxFileSize: Int64 = 300 * 1024 * 1024
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                VStack(spacing: 12) {
                    statusContentView
                    summarizeButton
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "FAFAFA"))
            
            // Toast message
            if let toast = toastMessage {
                toastView(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toastMessage)
                    .zIndex(9999)
                    .padding(.top, 16)
            }
        }
        .interactiveDismissDisabled(isUploading)
        .onAppear {
            // Reset khi sheet được mở
            if uploadStatus != .loading && uploadStatus != .success {
                uploadStatus = .idle
            }
        }
        .onDisappear {
            // Reset khi sheet đóng (trừ khi đang navigate)
            if uploadStatus != .success {
                uploadStatus = .idle
                uploadedFileURL = nil
                selectedFile = nil
                selectedFileData = nil
            }
        }
        .sheet(isPresented: $showingUnifiedPicker) {
            UnifiedMediaPicker(
                selectedFile: $selectedFile,
                selectedFileData: $selectedFileData
            )
        }
        .onChange(of: selectedFile) { newFile in
            handleFileChange(newFile)
        }
        .onChange(of: selectedFileData) { newData in
            handleDataChange(newData)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isUploading: Bool {
        if case .loading = uploadStatus {
            return true
        }
        return false
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Invisible placeholder để căn giữa title
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.custom("Overused Grotesk", size: 16))
                    .foregroundColor(.clear)
                    .frame(width: 28, height: 28)
            }
            .opacity(0)
            
            Spacer()
            
            // Title
            Text("Upload File")
                .font(.labelMedium)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            // Close button
            if uploadStatus != .loading {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.custom("Overused Grotesk", size: 16))
                        .foregroundColor(.textPrimary)
                        .frame(width: 28, height: 28)
                }
            } else {
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Status Content View
    
    @ViewBuilder
    private var statusContentView: some View {
        ZStack(alignment: .topTrailing) {
            // Content
            Group {
                switch uploadStatus {
                case .idle:
                    uploadAreaView
                case .preview:
                    previewContent
                case .loading:
                    loadingContent
                case .success:
                    successContent
                case .failed(let errorMessage):
                    failedContent(errorMessage: errorMessage)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Edit button
            if (uploadStatus == .preview || uploadStatus == .success), selectedFile != nil {
                Button(action: {
                    showingUnifiedPicker = true
                }) {
                    Image("edit_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                .padding(6)
                .offset(x: 8, y: -16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.primaryOrange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primaryOrange, lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    // MARK: - Summarize Button
    
    @ViewBuilder
    private var summarizeButton: some View {
        switch uploadStatus {
        case .failed:
            Button(action: {
                uploadStatus = .idle
                selectedFile = nil
                selectedFileData = nil
                uploadedFileURL = nil
            }) {
                Text("Try Again")
                    .font(.labelMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.primaryOrange)
                    .cornerRadius(16)
            }
        default:
            Button(action: {
                handleSummarize()
            }) {
                Text("Sumarize")
                    .font(.labelMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(buttonBackgroundColor)
                    .cornerRadius(16)
            }
            .disabled(uploadStatus == .idle || uploadStatus == .loading)
            .opacity(uploadStatus == .loading ? 0.4 : 1.0)
        }
    }
    
    private var buttonBackgroundColor: Color {
        uploadStatus == .idle 
            ? Color.primaryOrange.opacity(0.4)
            : Color.primaryOrange
    }
    
    // MARK: - State Views
    
    private var uploadAreaView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primaryOrange)
                    .frame(width: 48, height: 48)
                
                Image("upload")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            }
            
            VStack(spacing: 4) {
                Text("Upload Audio or Video")
                    .font(Font.custom("Overused Grotesk", size: 16).weight(.bold))
                    .foregroundColor(Color(hex: "#020202"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(24 - 16)
                
                HStack(spacing: 8) {
                    Text("MP3, WAV, MP4, MOV")
                        .font(.custom("Overused Grotesk", size: 13))
                        .foregroundColor(Color(hex: "#717171"))
                        .fontWeight(.regular)
                        .lineSpacing(16 - 13)
                    
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 4, height: 4)
                    
                    Text("Up to 300MB")
                        .font(.custom("Overused Grotesk", size: 13))
                        .foregroundColor(Color(hex: "#717171"))
                        .fontWeight(.regular)
                        .lineSpacing(16 - 13)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingUnifiedPicker = true
        }
    }
    
    private var previewContent: some View {
        VStack(spacing: 16) {
            if let file = selectedFile, let data = selectedFileData {
                LocalFilePreviewView(file: file, data: data)
                    .frame(width: 85, height: 48)
                    .cornerRadius(4)
                    .clipped()
                
                VStack(alignment: .center, spacing: 4) {
                    Text(formatFileName(file.name))
                        .font(.custom("Overused Grotesk", size: 16).weight(.bold))
                        .foregroundColor(Color(hex: "#020202"))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    
                    Text(formatFileSize(data.count))
                        .font(.custom("Overused Grotesk", size: 13))
                        .foregroundColor(Color(hex: "#717171"))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.primaryOrange))
                .scaleEffect(1.5)
                .frame(width: 48, height: 48)
            
            VStack(spacing: 4) {
                Text("Uploading...")
                    .font(.custom("Overused Grotesk", size: 16).weight(.bold))
                    .foregroundColor(Color(hex: "#020202"))
                    .multilineTextAlignment(.center)
                
                if let file = selectedFile {
                    Text(file.name)
                        .font(.custom("Overused Grotesk", size: 13))
                        .foregroundColor(Color(hex: "#717171"))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var successContent: some View {
        VStack(spacing: 16) {
            if let file = selectedFile {
                VStack(spacing: 16) {
                    RemoteFilePreviewView(file: file)
                        .frame(width: 85, height: 48)
                        .cornerRadius(4)
                        .clipped()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text(formatFileName(file.name))
                            .font(.custom("Overused Grotesk", size: 16).weight(.bold))
                            .foregroundColor(Color(hex: "#020202"))
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                        
                        if let size = file.size {
                            Text(formatFileSize(size))
                                .font(.custom("Overused Grotesk", size: 13))
                                .foregroundColor(Color(hex: "#717171"))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
    }
    
    private func failedContent(errorMessage: String) -> some View {
        VStack(spacing: 16) {
            Image("error_icon")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            
            VStack(spacing: 4) {
                Text("Upload Failed")
                    .font(.custom("Overused Grotesk", size: 16).weight(.bold))
                    .foregroundColor(Color(hex: "#020202"))
                    .multilineTextAlignment(.center)
                
                Text(errorMessage)
                    .font(.custom("Overused Grotesk", size: 13))
                    .foregroundColor(Color(hex: "#717171"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Toast View
    
    private func toastView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.custom("Overused Grotesk", size: 16))
            
            Text(message)
                .font(.custom("Overused Grotesk", size: 14))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                toastMessage = nil
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.custom("Overused Grotesk", size: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#FF3D33"))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Handlers
    
    private func handleFileChange(_ newFile: FileAttachment?) {
        // Nếu đang ở success hoặc loading, không xử lý
        if case .success = uploadStatus { return }
        if case .loading = uploadStatus { return }
        
        // Nếu file đã có URL (đã upload), không xử lý
        if let file = newFile, !file.url.isEmpty, file.url.hasPrefix("http") {
            return
        }
        
        // Validate file
        if let file = newFile, let data = selectedFileData {
            validateAndSetFile(file: file, data: data)
        } else {
            uploadStatus = .idle
            uploadedFileURL = nil
        }
    }
    
    private func handleDataChange(_ newData: Data?) {
        // Nếu đang ở success hoặc loading, không xử lý
        if case .success = uploadStatus { return }
        if case .loading = uploadStatus { return }
        
        // Validate file
        if let file = selectedFile, let data = newData {
            validateAndSetFile(file: file, data: data)
        }
    }
    
    private func validateAndSetFile(file: FileAttachment, data: Data) {
        let fileSize = Int64(data.count)
        
        if fileSize > maxFileSize {
            toastMessage = "File size exceeds 300MB limit"
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    toastMessage = nil
                }
            }
            uploadStatus = .idle
            selectedFile = nil
            selectedFileData = nil
        } else {
            uploadStatus = .preview
        }
    }
    
    private func handleSummarize() {
        guard let file = selectedFile, let data = selectedFileData else { return }
        
        // Validate file size
        let fileSize = Int64(data.count)
        if fileSize > maxFileSize {
            uploadStatus = .failed("File size exceeds 300MB limit")
            return
        }
        
        // Bắt đầu upload
        uploadStatus = .loading
        
        Task {
            do {
                // Upload file
                let fileURL = try await StorageService.shared.uploadFile(
                    data: data,
                    fileName: file.name,
                    fileType: file.type,
                    customMaxSize: Int(maxFileSize)
                )
                
                uploadedFileURL = fileURL
                
                // Nếu là video hoặc audio → Transcribe
                if file.type == .video || file.type == .audio {
                    await MainActor.run {
                        uploadStatus = .loading
                    }
                    
                    let userId = 8042467986
                    let result: TranscribeResult
                    
                    if file.type == .audio {
                        result = try await TranscribeService.shared.transcribeAudio(
                            audioData: data,
                            fileName: file.name,
                            userId: userId
                        )
                    } else {
                        result = try await TranscribeService.shared.transcribeVideoURL(
                            videoURL: fileURL,
                            userId: userId
                        )
                    }
                    
                    // Tạo conversation
                    let conversationTitle = (file.name as NSString).deletingPathExtension
                    let newConversation = try await SupabaseService.shared.createConversation(title: conversationTitle)
                    
                    // Tạo user message
                    _ = try await SupabaseService.shared.createMessage(
                        conversationId: newConversation.id,
                        role: .user,
                        content: "📎 Sent a file",
                        fileUrl: fileURL,
                        fileName: file.name,
                        fileType: file.type.rawValue,
                        fileSize: data.count
                    )
                    
                    // Tạo assistant message với transcription
                    let transcriptionFileName = "transcript_\(Date().timeIntervalSince1970).txt"
                    _ = try await SupabaseService.shared.createMessage(
                        conversationId: newConversation.id,
                        role: .assistant,
                        content: result.message,
                        fileUrl: result.transcriptionURL,
                        fileName: transcriptionFileName,
                        fileType: "other",
                        fileSize: nil
                    )
                    
                    // Cập nhật timestamp
                    try await SupabaseService.shared.updateConversationTimestamp(conversationId: newConversation.id)
                    
                    // Success và navigate
                    await MainActor.run {
                        uploadStatus = .success
                        
                        // Đợi một chút để user thấy success state
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await MainActor.run {
                                isPresented = false
                                onTranscribeSuccess?(newConversation)
                            }
                        }
                    }
                } else {
                    // Không phải video/audio → chỉ upload và hiển thị success
                    await MainActor.run {
                        uploadStatus = .success
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage: String
                    if let storageError = error as? StorageError {
                        errorMessage = storageError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    uploadStatus = .failed(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatFileName(_ fileName: String) -> String {
        let maxLength = 20
        let fileExtension = (fileName as NSString).pathExtension
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        if nameWithoutExtension.count <= maxLength {
            return fileName
        }
        
        let extensionLength = fileExtension.isEmpty ? 0 : fileExtension.count + 1
        let availableLength = maxLength - extensionLength - 3
        
        if availableLength > 0 {
            let truncatedName = String(nameWithoutExtension.prefix(availableLength))
            return fileExtension.isEmpty ? "\(truncatedName)..." : "\(truncatedName)....\(fileExtension)"
        } else {
            return fileExtension.isEmpty ? "..." : "....\(fileExtension)"
        }
    }
}

// MARK: - Local File Preview View

struct LocalFilePreviewView: View {
    let file: FileAttachment
    let data: Data
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        Group {
            switch file.type {
            case .image:
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 85, height: 48)
                        .clipped()
                        .cornerRadius(4)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 85, height: 48)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.custom("Overused Grotesk", size: 16))
                                .foregroundColor(.white)
                        )
                }
                
            case .video:
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 85, height: 48)
                        .clipped()
                        .cornerRadius(4)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 85, height: 48)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                        .onAppear {
                            extractVideoThumbnail()
                        }
                }
                
            case .audio:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.custom("Overused Grotesk", size: 20))
                            .foregroundColor(.white)
                    )
                
            case .other:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.custom("Overused Grotesk", size: 20))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    private func extractVideoThumbnail() {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        
        guard (try? data.write(to: tempFile)) != nil else {
            return
        }
        
        let asset = AVAsset(url: tempFile)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        Task {
            do {
                let cgImage: CGImage
                if #available(iOS 16.0, *) {
                    cgImage = try await imageGenerator.image(at: time).image
                } else {
                    // iOS 15: dùng synchronous method
                    cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                }
                let uiImage = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    videoThumbnail = uiImage
                }
                
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                await MainActor.run {
                    videoThumbnail = nil
                }
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
    }
}

// MARK: - Remote File Preview View

struct RemoteFilePreviewView: View {
    let file: FileAttachment
    
    var body: some View {
        Group {
            switch file.type {
            case .image:
                AsyncImage(url: URL(string: file.url)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 85, height: 48)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 85, height: 48)
                            .clipped()
                            .cornerRadius(4)
                    case .failure:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 85, height: 48)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.custom("Overused Grotesk", size: 16))
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
            case .video:
                AsyncImage(url: URL(string: file.url)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 85, height: 48)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 85, height: 48)
                            .clipped()
                            .cornerRadius(4)
                    case .failure:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 85, height: 48)
                    @unknown default:
                        EmptyView()
                    }
                }
                
            case .audio:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.custom("Overused Grotesk", size: 20))
                            .foregroundColor(.white)
                    )
                
            case .other:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.custom("Overused Grotesk", size: 20))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UploadFileModal(
        isPresented: .constant(true),
        selectedFile: .constant(nil),
        selectedFileData: .constant(nil)
    )
}
