//
//  FileAttachment.swift
//  Chat-Ai
//
//  Model đại diện cho file đính kèm trong tin nhắn
//

import Foundation

// MARK: - FileAttachment

/// Đại diện cho một file đính kèm (ảnh, video, audio)
struct FileAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String           // URL của file (từ Supabase Storage)
    let name: String          // Tên file gốc
    let type: FileType        // Loại file
    let size: Int?            // Kích thước file (bytes)
    
    // MARK: - FileType
    
    /// Loại file được hỗ trợ
    enum FileType: String, Codable {
        case image = "image"
        case video = "video"
        case audio = "audio"
        case other = "other"
        
        /// Icon cho từng loại file
        var icon: String {
            switch self {
            case .image: return "photo"
            case .video: return "video"
            case .audio: return "waveform"
            case .other: return "doc"
            }
        }
        
        /// Màu sắc cho từng loại file
        var color: String {
            switch self {
            case .image: return "blue"
            case .video: return "purple"
            case .audio: return "green"
            case .other: return "gray"
            }
        }
    }
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        url: String,
        name: String,
        type: FileType,
        size: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.type = type
        self.size = size
    }
    
    // MARK: - Helpers
    
    /// Format kích thước file thành string dễ đọc
    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    /// Kiểm tra file có phải là ảnh không
    var isImage: Bool {
        return type == .image
    }
    
    /// Kiểm tra file có phải là video không
    var isVideo: Bool {
        return type == .video
    }
    
    /// Kiểm tra file có phải là audio không
    var isAudio: Bool {
        return type == .audio
    }
}

// MARK: - FileType Detection

extension FileAttachment {
    /// Xác định loại file từ MIME type hoặc extension
    static func detectFileType(from mimeType: String?, or fileName: String) -> FileType {
        // Kiểm tra MIME type trước
        if let mimeType = mimeType?.lowercased() {
            if mimeType.hasPrefix("image/") {
                return .image
            } else if mimeType.hasPrefix("video/") {
                return .video
            } else if mimeType.hasPrefix("audio/") {
                return .audio
            }
        }
        
        // Fallback: Kiểm tra extension
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        // Image extensions
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"]
        if imageExtensions.contains(fileExtension) {
            return .image
        }
        
        // Video extensions
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v"]
        if videoExtensions.contains(fileExtension) {
            return .video
        }
        
        // Audio extensions
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac"]
        if audioExtensions.contains(fileExtension) {
            return .audio
        }
        
        return .other
    }
}

