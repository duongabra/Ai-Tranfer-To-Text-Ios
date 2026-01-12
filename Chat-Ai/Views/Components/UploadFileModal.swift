//
//  UploadFileModal.swift
//  Chat-Ai
//
//  Modal để upload file (ảnh/video/audio)
//

import SwiftUI
import UIKit
import AVKit

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
    
    @State private var showingUnifiedPicker = false
    @State private var uploadStatus: UploadStatus = .idle
    @State private var uploadedFileURL: String? = nil
    @State private var isUploaded: Bool = false // Flag để track xem đã upload thành công chưa
    
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
        .sheet(isPresented: $showingUnifiedPicker) {
            UnifiedMediaPicker(
                selectedFile: $selectedFile,
                selectedFileData: $selectedFileData
            )
        }
        .onChange(of: selectedFile) { newFile in
            // Nếu đã upload thành công, không xử lý onChange để tránh reset về preview
            if isUploaded {
                print("⚠️ Ignoring onChange because file already uploaded (isUploaded = true)")
                return
            }
            // Nếu đang ở success state, không xử lý onChange để tránh reset về preview
            if case .success = uploadStatus {
                print("⚠️ Ignoring onChange because already in success state")
                return
            }
            handleFileSelection(newFile)
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
                    .font(.system(size: 16))
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
                    .font(.system(size: 16))
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
        Group {
            switch uploadStatus {
            case .idle:
                uploadAreaView
                    .onAppear {
                        print("📋 Current status: .idle")
                    }
            case .preview:
                previewView
                    .onAppear {
                        print("📋 Current status: .preview")
                    }
            case .loading:
                loadingView
                    .onAppear {
                        print("📋 Current status: .loading")
                    }
            case .success:
                successView
                    .onAppear {
                        print("✅ Success view is being displayed - uploadStatus = .success")
                    }
            case .failed(let errorMessage):
                failedView(errorMessage: errorMessage)
                    .onAppear {
                        print("❌ Current status: .failed(\(errorMessage))")
                    }
            }
        }
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
    
    /// Upload area view (idle state)
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
                    .font(Font.custom("Overused Grotesk", size: 16).weight(.semibold))
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.primaryOrange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primaryOrange, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onTapGesture {
            showingUnifiedPicker = true
        }
    }
    
    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            // Spinner icon (48x48)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.primaryOrange))
                .scaleEffect(1.5)
                .frame(width: 48, height: 48)
            
            // Text
            VStack(spacing: 4) {
                Text("Uploading...")
                    .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.primaryOrange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primaryOrange, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .cornerRadius(16)
    }
    
    /// Preview view (trước khi upload)
    private var previewView: some View {
        VStack(spacing: 12) {
            // File preview
            if let file = selectedFile, let data = selectedFileData {
                // Preview từ data local
                LocalFilePreviewView(file: file, data: data)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                
                // File info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                            .foregroundColor(Color(hex: "#020202"))
                            .lineLimit(1)
                        
                        Text(formatFileSize(data.count))
                            .font(.custom("Overused Grotesk", size: 13))
                            .foregroundColor(Color(hex: "#717171"))
                    }
                    
                    Spacer()
                    
                    // Edit icon (placeholder - sẽ implement sau)
                    Button(action: {
                        // TODO: Edit file name
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#FF0000"))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.primaryOrange.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    /// Success view
    private var successView: some View {
        ZStack(alignment: .topTrailing) {
            // Content - căn giữa hoàn toàn
            VStack(spacing: 16) {
                // File preview và info
                if let file = selectedFile {
                    VStack(spacing: 16) {
                        // Preview thumbnail (85x48 với padding 4px bên trong)
                        ZStack {
                            RemoteFilePreviewView(file: file)
                                .frame(width: 85, height: 48)
                                .cornerRadius(4)
                                .clipped()
                        }
                        .padding(4)
                        
                        // File info (căn giữa)
                        VStack(alignment: .center, spacing: 4) {
                            Text(file.name)
                                .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
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
            .frame(maxWidth: .infinity)
            .padding(24)
            
            // Edit button ở góc trên phải (absolute position)
            if selectedFile != nil {
                Button(action: {
                    // TODO: Edit file name
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#CC0A00"))
                        .frame(width: 24, height: 24)
                }
                .padding(6)
                .offset(x: -8, y: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.primaryOrange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#D87757"), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .cornerRadius(16)
    }
    
    /// Failed view
    private func failedView(errorMessage: String) -> some View {
        VStack(spacing: 16) {
            // Error icon (48x48 với màu #FF3D33)
            ZStack {
                Circle()
                    .fill(Color(hex: "#FF3D33").opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "exclamationmark")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FF3D33"))
            }
            
            // Error text
            VStack(spacing: 4) {
                Text("Upload Failed")
                    .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
                    .foregroundColor(Color(hex: "#020202"))
                    .multilineTextAlignment(.center)
                
                Text(errorMessage)
                    .font(.custom("Overused Grotesk", size: 13))
                    .foregroundColor(Color(hex: "#717171"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
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
            uploadStatus = .failed("File size exceeds 300MB limit")
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
                // Upload file lên Supabase Storage với maxSize 300MB
                let fileURL = try await StorageService.shared.uploadFile(
                    data: data,
                    fileName: file.name,
                    fileType: file.type,
                    customMaxSize: Int(maxFileSize)
                )
                
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
}

// MARK: - Local File Preview View (từ data local)

/// Preview file từ data local (chưa upload)
struct LocalFilePreviewView: View {
    let file: FileAttachment
    let data: Data
    @State private var tempVideoURL: URL?
    @State private var tempAudioURL: URL?
    
    var body: some View {
        Group {
            switch file.type {
            case .image:
                // Image preview từ data
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                
            case .video:
                // Video preview từ data (tạo temp URL)
                if let tempURL = tempVideoURL {
                    InlineVideoPlayer(url: tempURL)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                        .onAppear {
                            tempVideoURL = createTempVideoURL()
                        }
                }
                
            case .audio:
                // Audio preview
                if let tempURL = tempAudioURL {
                    InlineAudioPlayer(url: tempURL, fileName: file.name)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primaryOrange.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .tint(.primaryOrange)
                        )
                        .onAppear {
                            tempAudioURL = createTempAudioURL()
                        }
                }
                
            case .other:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
        }
        .onDisappear {
            // Cleanup temp files
            cleanupTempFiles()
        }
    }
    
    /// Tạo temporary URL cho video từ data
    private func createTempVideoURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        
        do {
            try data.write(to: tempFile)
            return tempFile
        } catch {
            print("❌ Failed to create temp video URL: \(error)")
            return nil
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
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
            case .video:
                // Video thumbnail (85x48) - chỉ hiển thị thumbnail với play icon
                ZStack {
                    // Background với opacity 0.4
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 85, height: 48)
                    
                    // Thumbnail image nếu có (từ video URL)
                    AsyncImage(url: URL(string: file.url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 85, height: 48)
                                .clipped()
                                .cornerRadius(4)
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    // Play icon overlay ở giữa
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
            case .audio:
                // Audio icon placeholder (85x48)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
                
            case .other:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 85, height: 48)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20))
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

