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
    @State private var isUploaded: Bool = false // Flag để track xem đã upload thành công chưa
    @State private var previousFileId: String? = nil // Track file cũ để phát hiện file mới
    @State private var toastMessage: String? = nil // Toast message để hiển thị lỗi
    
    // Giới hạn file size: 300MB
    private let maxFileSize: Int64 = 300 * 1024 * 1024
    
    var body: some View {
        if isPresented {
            modalContent
                .onAppear {
                    // Reset flag khi modal được mở
                    if !isUploaded {
                        print("📱 Modal opened, resetting states")
                        uploadStatus = .idle
                        isUploaded = false
                    }
                }
        } else {
            // Reset khi modal đóng
            Color.clear
                .onAppear {
                    print("📱 Modal closed, resetting all states")
                    uploadStatus = .idle
                    isUploaded = false
                    uploadedFileURL = nil
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
        .overlay(alignment: .top) {
            // Toast message - đặt ở top với zIndex cao để không bị che
            if let toast = toastMessage {
                toastView(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toastMessage)
                    .zIndex(9999)
            }
        }
        .sheet(isPresented: $showingUnifiedPicker) {
            UnifiedMediaPicker(
                selectedFile: $selectedFile,
                selectedFileData: $selectedFileData
            )
        }
        .onChange(of: selectedFile) { newFile in
            // Tạo ID để so sánh file (dùng name + url)
            let newFileId = newFile.map { "\($0.name)-\($0.url)" }
            
            // So sánh với file cũ TRƯỚC khi cập nhật previousFileId
            let isNewFile: Bool
            if let newFileId = newFileId, let previousId = previousFileId {
                isNewFile = newFileId != previousId
            } else {
                isNewFile = newFile != nil // Nếu không có previousId, coi như file mới
            }
            
            // Nếu chọn file mới (khác file cũ), clear file cũ và reset state
            if isNewFile {
                // File mới được chọn từ edit button, clear state cũ
                uploadStatus = .idle
                uploadedFileURL = nil
                isUploaded = false
                // Note: selectedFileData sẽ được cập nhật tự động từ UnifiedMediaPicker
            }
            
            // Cập nhật previousFileId SAU khi đã xử lý
            previousFileId = newFileId
            
            // Nếu đã upload thành công và không phải file mới, không xử lý onChange
            if isUploaded && !isNewFile {
                print("⚠️ Ignoring onChange because file already uploaded (isUploaded = true)")
                return
            }
            
            // Nếu đang ở success state và không phải file mới, không xử lý onChange
            if case .success = uploadStatus, !isNewFile {
                print("⚠️ Ignoring onChange because already in success state")
                return
            }
            
            handleFileSelection(newFile)
        }
        .onChange(of: selectedFileData) { newData in
            // Khi selectedFileData thay đổi, đảm bảo preview được cập nhật
            // Nếu có file và data mới, validate lại
            if let file = selectedFile, let data = newData {
                // Luôn validate file khi có data mới (bao gồm cả file quá lớn)
                validateAndSetFile(file: file, data: data)
            }
        }
    }
    
    private var backgroundBlur: some View {
        Color.white.opacity(0.3)
            .ignoresSafeArea(edges: .all)
            .background(.ultraThinMaterial)
            .onTapGesture {
                isPresented = false
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
                isPresented = false
            }) {
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
            
            // Close button (right)
            Button(action: {
                isPresented = false 
            }) {
                Image(systemName: "xmark")
                    .font(.custom("Overused Grotesk", size: 16))
                    .foregroundColor(.textPrimary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private var contentView: some View {
        VStack(spacing: 12) {
            statusContentView
            summarizeButton
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private var statusContentView: some View {
        // Container chung với dashed border cho tất cả states
        ZStack(alignment: .topTrailing) {
            // Content - căn giữa
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
            
            // Edit button hiển thị ở preview và success state, ở góc trên cùng bên phải của container
            if (uploadStatus == .preview || uploadStatus == .success), selectedFile != nil {
                Button(action: {
                    // Chỉ mở file picker, không clear state ngay
                    // File cũ sẽ được clear khi chọn file mới
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
                .stroke(Color(hex: "#D87757"), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var summarizeButton: some View {
        switch uploadStatus {
        case .failed:
            // Try Again button cho failed state
            Button(action: {
                // Reset và cho phép chọn lại file
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
            // Sumarize button cho các state khác
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
        }
    }
    
    private var buttonBackgroundColor: Color {
        uploadStatus == .idle 
            ? Color.primaryOrange.opacity(0.4)
            : Color.primaryOrange
    }
    
    // MARK: - Helpers
    
    private func handleFileSelection(_ newFile: FileAttachment?) {
        // Nếu đang ở success state và file có URL (đã upload), không reset về preview
        if case .success = uploadStatus, let file = newFile, !file.url.isEmpty {
            // File đã upload thành công, giữ nguyên success state
            return
        }
        
        if let file = newFile, let data = selectedFileData {
            validateAndSetFile(file: file, data: data)
        } else {
            uploadStatus = .idle
            uploadedFileURL = nil
        }
    }
    
    // MARK: - Views
    
    /// Upload area view (idle state) - State 1
    private var uploadAreaView: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.primaryOrange)
                    .frame(width: 48, height: 48)
                
                Image("upload")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            }
            
            // Title
            VStack(spacing: 4) {
                Text("Upload Audio or Video")
                    .font(Font.custom("Overused Grotesk", size: 16).weight(.bold))
                    .foregroundColor(Color(hex: "#020202"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(24 - 16)
                
                // File formats and size
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
    
    /// Preview content (State 2) - chỉ nội dung bên trong, căn giữa
    private var previewContent: some View {
        VStack(spacing: 16) {
            // File preview - thumbnail nhỏ 85x48
            if let file = selectedFile, let data = selectedFileData {
                // Preview từ data local - thumbnail nhỏ như success state
                // Dùng .id() để force refresh khi file hoặc data thay đổi
                LocalFilePreviewView(file: file, data: data)
                    .id("\(file.name)-\(data.count)") // Unique ID để force refresh
                    .frame(width: 85, height: 48)
                    .cornerRadius(4)
                    .clipped()
                
                // File info - căn giữa
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
    
    /// Loading content (State 3) - chỉ nội dung bên trong
    private var loadingContent: some View {
        VStack(spacing: 16) {
            // Spinner icon (48x48)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.primaryOrange))
                .scaleEffect(1.5)
                .frame(width: 48, height: 48)
            
            // Text
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
    
    /// Success content (State 4) - chỉ nội dung bên trong, căn giữa
    private var successContent: some View {
        VStack(spacing: 16) {
            // File preview và info
            if let file = selectedFile {
                VStack(spacing: 16) {
                    // Preview thumbnail (85x48)
                    RemoteFilePreviewView(file: file)
                        .frame(width: 85, height: 48)
                        .cornerRadius(4)
                        .clipped()
                    
                    // File info (căn giữa)
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
    
    /// Failed content - chỉ nội dung bên trong
    private func failedContent(errorMessage: String) -> some View {
        VStack(spacing: 16) {
            // Error icon (48x48 với màu #FF3D33)
            ZStack {
                Image("error_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            }
            
            // Error text
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
    
    /// Toast message hiển thị lỗi
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
    
    // MARK: - Helpers
    
    /// Validate file size và set status
    private func validateAndSetFile(file: FileAttachment, data: Data) {
        // Nếu file đã có URL (đã upload), không reset về preview
        if !file.url.isEmpty && file.url.hasPrefix("http") {
            // File đã upload, giữ nguyên success state nếu đang ở success
            if case .success = uploadStatus {
                return
            }
        }
        
        let fileSize = Int64(data.count)
        
        if fileSize > maxFileSize {
            // Hiển thị toast error
            toastMessage = "File size exceeds 300MB limit"
            // Auto dismiss toast sau 3 giây
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    toastMessage = nil
                }
            }
            // Reset về idle state
            uploadStatus = .idle
            selectedFile = nil
            selectedFileData = nil
        } else {
            // File hợp lệ, hiển thị preview (chưa upload)
            // Chỉ set preview nếu chưa ở success state
            if case .success = uploadStatus {
                return
            }
            uploadStatus = .preview
        }
    }
    
    /// Upload file và chuyển sang success state
    private func handleSummarize() {
        guard let file = selectedFile, let data = selectedFileData else { return }
        
        // Validate lại file size
        let fileSize = Int64(data.count)
        if fileSize > maxFileSize {
            uploadStatus = .failed("File size exceeds 300MB limit")
            return
        }
        
        // Bắt đầu upload
        uploadStatus = .loading
        
        Task {
            do {
                // Bước 1: Upload file lên Supabase Storage với maxSize 300MB
                let fileURL = try await StorageService.shared.uploadFile(
                    data: data,
                    fileName: file.name,
                    fileType: file.type,
                    customMaxSize: Int(maxFileSize)
                )
                
                print("✅ File uploaded successfully: \(fileURL)")
                
                // Bước 2: Nếu là video hoặc audio → Transcribe
                if file.type == .video || file.type == .audio {
                    await MainActor.run {
                        uploadStatus = .loading
                    }
                    
                    print("🎵 Starting transcription for \(file.type.rawValue)...")
                    
                    // Gọi TranscribeService
                    let userId = 8042467986 // Fixed user_id for transcribe API
                    let transcription: String
                    
                    if file.type == .audio {
                        // Transcribe audio
                        transcription = try await TranscribeService.shared.transcribeAudio(
                            audioData: data,
                            fileName: file.name,
                            userId: userId
                        )
                    } else {
                        // Transcribe video (sử dụng file URL)
                        print("📹 Calling transcribeVideoURL with URL: \(fileURL)")
                        let transcribeStartTime = Date()
                        transcription = try await TranscribeService.shared.transcribeVideoURL(
                            videoURL: fileURL,
                            userId: userId
                        )
                        let transcribeElapsed = Date().timeIntervalSince(transcribeStartTime)
                        print("⏱️ Transcription took \(String(format: "%.2f", transcribeElapsed)) seconds")
                    }
                    
                    print("✅ Transcription successful: \(transcription.prefix(100))...")
                    
                    // Bước 3: Tạo conversation mới với title = fileName (không có extension)
                    let conversationTitle = (file.name as NSString).deletingPathExtension
                    let newConversation = try await SupabaseService.shared.createConversation(title: conversationTitle)
                    
                    print("✅ Conversation created: \(newConversation.id)")
                    
                    // Bước 4: Tạo message đầu tiên với transcription text
                    let firstMessage = try await SupabaseService.shared.createMessage(
                        conversationId: newConversation.id,
                        role: .user,
                        content: transcription,
                        fileUrl: fileURL,
                        fileName: file.name,
                        fileType: file.type.rawValue,
                        fileSize: data.count
                    )
                    
                    print("✅ First message created: \(firstMessage.id)")
                    
                    // Bước 5: Cập nhật timestamp của conversation
                    try await SupabaseService.shared.updateConversationTimestamp(conversationId: newConversation.id)
                    
                    // Bước 6: Navigate đến ChatView
                    await MainActor.run {
                        uploadStatus = .success
                        isUploaded = true
                        uploadedFileURL = fileURL
                        
                        // Cập nhật selectedFile với URL mới
                        selectedFile = FileAttachment(
                            url: fileURL,
                            name: file.name,
                            type: file.type,
                            size: file.size
                        )
                        
                        // Đóng modal
                        isPresented = false
                        
                        // Call callback để navigate đến ChatView
                        onTranscribeSuccess?(newConversation)
                    }
                } else {
                    // Không phải video/audio → chỉ upload và hiển thị success
                    await MainActor.run {
                        uploadedFileURL = fileURL
                        
                        // Set flag và success status TRƯỚC khi cập nhật selectedFile
                        // để tránh onChange trigger và reset về preview
                        isUploaded = true
                        uploadStatus = .success
                        print("✅ Upload successful, status changed to .success, isUploaded = true")
                        
                        // Cập nhật selectedFile với URL mới sau khi đã set success
                        selectedFile = FileAttachment(
                            url: fileURL,
                            name: file.name,
                            type: file.type,
                            size: file.size
                        )
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
    
    /// Format file size thành string
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Format file name: giới hạn max 20 ký tự, nếu dài quá thì "xxx....mp4"
    private func formatFileName(_ fileName: String) -> String {
        let maxLength = 20
        
        // Lấy extension
        let fileExtension = (fileName as NSString).pathExtension
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // Nếu tên file (không có extension) <= maxLength, trả về nguyên
        if nameWithoutExtension.count <= maxLength {
            return fileName
        }
        
        // Nếu có extension, tính toán độ dài phần name
        let extensionLength = fileExtension.isEmpty ? 0 : fileExtension.count + 1 // +1 cho dấu chấm
        let availableLength = maxLength - extensionLength - 3 // -3 cho "..."
        
        if availableLength > 0 {
            let truncatedName = String(nameWithoutExtension.prefix(availableLength))
            return fileExtension.isEmpty ? "\(truncatedName)..." : "\(truncatedName)....\(fileExtension)"
        } else {
            // Nếu extension quá dài, chỉ hiển thị extension
            return fileExtension.isEmpty ? "..." : "....\(fileExtension)"
        }
    }
}

// MARK: - Local File Preview View (từ data local)

/// Preview file từ data local (chưa upload)
struct LocalFilePreviewView: View {
    let file: FileAttachment
    let data: Data
    @State private var tempVideoURL: URL?
    @State private var tempAudioURL: URL?
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        Group {
            switch file.type {
            case .image:
                // Image preview từ data - thumbnail nhỏ 85x48
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
                // Video preview từ data - chỉ hiển thị thumbnail (frame đầu tiên), không play được
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
                // Audio preview - thumbnail nhỏ 85x48
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.custom("Overused Grotesk", size: 20))
                            .foregroundColor(.white)
                    )
                
            case .other:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.custom("Overused Grotesk", size: 40))
                            .foregroundColor(.gray)
                    )
            }
        }
        .onDisappear {
            // Cleanup temp files
            cleanupTempFiles()
        }
    }
    
    /// Extract thumbnail từ video data (frame đầu tiên)
    private func extractVideoThumbnail() {
        // Tạo temp URL từ data
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        
        guard (try? data.write(to: tempFile)) != nil else {
            print("❌ Failed to create temp video URL")
            return
        }
        
        // Extract thumbnail từ frame đầu tiên
        let asset = AVAsset(url: tempFile)
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
                
                // Cleanup temp file
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                print("❌ Failed to extract video thumbnail: \(error)")
                await MainActor.run {
                    videoThumbnail = nil
                }
                // Cleanup temp file
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
    }
    
    /// Tạo temporary URL cho audio từ data
    private func createTempAudioURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileExtension = (file.name as NSString).pathExtension.isEmpty ? "mp3" : (file.name as NSString).pathExtension
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        
        do {
            try data.write(to: tempFile)
            return tempFile
        } catch {
            print("❌ Failed to create temp audio URL: \(error)")
            return nil
        }
    }
    
    /// Cleanup temporary files
    private func cleanupTempFiles() {
        if let tempURL = tempVideoURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        if let tempURL = tempAudioURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}

// MARK: - Remote File Preview View (từ URL)

/// Preview file từ URL (đã upload)
struct RemoteFilePreviewView: View {
    let file: FileAttachment
    
    var body: some View {
        Group {
            switch file.type {
            case .image:
                // Image preview từ URL (thumbnail 85x48)
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
                // Video thumbnail (85x48) - chỉ hiển thị thumbnail, không có play button
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
                // Audio icon placeholder (85x48)
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

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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

