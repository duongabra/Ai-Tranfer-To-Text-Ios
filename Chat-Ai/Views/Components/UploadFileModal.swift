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
    
    // Giới hạn file size: 300MB
    private let maxFileSize: Int64 = 300 * 1024 * 1024
    
    var body: some View {
        if isPresented {
            modalContent
        }
    }
    
    // MARK: - Modal Content
    
    private var modalContent: some View {
        ZStack(alignment: .bottom) {
            backgroundBlur
            modalBody
        }
        .transition(.opacity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
        .sheet(isPresented: $showingUnifiedPicker) {
            UnifiedMediaPicker(
                selectedFile: $selectedFile,
                selectedFileData: $selectedFileData
            )
        }
        .onChange(of: selectedFile) { newFile in
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
        .ignoresSafeArea(edges: .bottom)
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
        switch uploadStatus {
        case .idle:
            uploadAreaView
        case .preview:
            previewView
        case .loading:
            loadingView
        case .success:
            successView
        case .failed(let errorMessage):
            failedView(errorMessage: errorMessage)
        }
    }
    
    private var summarizeButton: some View {
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
        .disabled(uploadStatus == .idle)
    }
    
    private var buttonBackgroundColor: Color {
        uploadStatus == .idle 
            ? Color.primaryOrange.opacity(0.4)
            : Color.primaryOrange
    }
    
    // MARK: - Helpers
    
    private func handleFileSelection(_ newFile: FileAttachment?) {
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
            // Spinner
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.primaryOrange))
                .scaleEffect(1.5)
                .frame(width: 48, height: 48)
            
            // Text
            VStack(spacing: 4) {
                Text("Uploading...")
                    .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
                    .foregroundColor(Color(hex: "#020202"))
                
                if let file = selectedFile {
                    Text(file.name)
                        .font(.custom("Overused Grotesk", size: 13))
                        .foregroundColor(Color(hex: "#717171"))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.primaryOrange.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 16)
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
        VStack(spacing: 12) {
            // File preview từ URL
            if let file = selectedFile {
                // Preview từ URL (đã upload)
                RemoteFilePreviewView(file: file)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                
                // File info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                            .foregroundColor(Color(hex: "#020202"))
                            .lineLimit(1)
                        
                        if let size = file.size {
                            Text(formatFileSize(size))
                                .font(.custom("Overused Grotesk", size: 13))
                                .foregroundColor(Color(hex: "#717171"))
                        }
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
    
    /// Failed view
    private func failedView(errorMessage: String) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 16) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                
                // Error text
                VStack(spacing: 4) {
                    Text("Upload Failed")
                        .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
                        .foregroundColor(Color(hex: "#020202"))
                    
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
            .cornerRadius(16)
            .padding(.horizontal, 16)
            
            // Try Again button
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
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helpers
    
    /// Validate file size và set status
    private func validateAndSetFile(file: FileAttachment, data: Data) {
        let fileSize = Int64(data.count)
        
        if fileSize > maxFileSize {
            uploadStatus = .failed("File size exceeds 300MB limit")
        } else {
            // File hợp lệ, hiển thị preview (chưa upload)
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
                    uploadStatus = .success
                    
                    // Cập nhật selectedFile với URL mới
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
                // Image preview từ URL
                AsyncImage(url: URL(string: file.url)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.1))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
            case .video:
                // Video preview từ URL
                InlineVideoPlayer(url: URL(string: file.url))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                
            case .audio:
                // Audio preview từ URL
                InlineAudioPlayer(url: URL(string: file.url), fileName: file.name)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                
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

