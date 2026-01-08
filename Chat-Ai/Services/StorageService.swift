//
//  StorageService.swift
//  Chat-Ai
//
//  Service để upload/download file từ Supabase Storage
//

import Foundation
import UIKit

// MARK: - StorageError

enum StorageError: LocalizedError {
    case invalidURL
    case uploadFailed
    case fileTooLarge(maxSize: Int)
    case unsupportedFileType
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL không hợp lệ"
        case .uploadFailed:
            return "Không thể upload file"
        case .fileTooLarge(let maxSize):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB]
            formatter.countStyle = .file
            let maxSizeString = formatter.string(fromByteCount: Int64(maxSize))
            return "File quá lớn. Kích thước tối đa: \(maxSizeString)"
        case .unsupportedFileType:
            return "Loại file không được hỗ trợ"
        case .unknownError(let error):
            return "Lỗi không xác định: \(error.localizedDescription)"
        }
    }
}

// MARK: - StorageService

actor StorageService {
    
    static let shared = StorageService()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Bucket name trong Supabase Storage
    private let bucketName = "chat-files"
    
    /// Giới hạn kích thước file (bytes)
    private let maxFileSize: [FileAttachment.FileType: Int] = [
        .image: 10 * 1024 * 1024,  // 10MB
        .video: 50 * 1024 * 1024,  // 50MB
        .audio: 20 * 1024 * 1024   // 20MB
    ]
    
    // MARK: - Upload File
    
    /// Upload file lên Supabase Storage
    /// - Parameters:
    ///   - data: Data của file
    ///   - fileName: Tên file
    ///   - fileType: Loại file
    /// - Returns: Public URL của file đã upload
    func uploadFile(data: Data, fileName: String, fileType: FileAttachment.FileType) async throws -> String {
        // Kiểm tra kích thước file
        if let maxSize = maxFileSize[fileType], data.count > maxSize {
            throw StorageError.fileTooLarge(maxSize: maxSize)
        }
        
        // Tạo unique file name (để tránh trùng)
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        
        // Tạo URL để upload
        let uploadURL = "\(AppConfig.supabaseURL)/storage/v1/object/\(bucketName)/\(uniqueFileName)"
        
        guard let url = URL(string: uploadURL) else {
            throw StorageError.invalidURL
        }
        
        // ✅ Lấy access token từ AuthService
        guard let accessToken = await AuthService.shared.getAccessToken() else {
            throw StorageError.uploadFailed
        }
        
        // Tạo request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") // ✅ Dùng access token
        
        // Set Content-Type dựa vào file type
        let contentType = getContentType(for: fileName, fileType: fileType)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = data
        
        // Upload file
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ Upload failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            if let errorString = String(data: responseData, encoding: .utf8) {
                print("❌ Error response: \(errorString)")
            }
            throw StorageError.uploadFailed
        }
        
        // Lấy public URL
        let publicURL = getPublicURL(for: uniqueFileName)
        
        print("✅ File uploaded successfully: \(publicURL)")
        return publicURL
    }
    
    // MARK: - Get Public URL
    
    /// Lấy public URL của file
    /// - Parameter fileName: Tên file trong storage
    /// - Returns: Public URL
    private func getPublicURL(for fileName: String) -> String {
        return "\(AppConfig.supabaseURL)/storage/v1/object/public/\(bucketName)/\(fileName)"
    }
    
    // MARK: - Get Content Type
    
    /// Lấy Content-Type cho file
    /// - Parameters:
    ///   - fileName: Tên file
    ///   - fileType: Loại file
    /// - Returns: Content-Type string
    private func getContentType(for fileName: String, fileType: FileAttachment.FileType) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileType {
        case .image:
            switch fileExtension {
            case "jpg", "jpeg": return "image/jpeg"
            case "png": return "image/png"
            case "gif": return "image/gif"
            case "heic": return "image/heic"
            case "heif": return "image/heif"
            case "webp": return "image/webp"
            default: return "image/jpeg"
            }
            
        case .video:
            switch fileExtension {
            case "mp4": return "video/mp4"
            case "mov": return "video/quicktime"
            case "avi": return "video/x-msvideo"
            case "mkv": return "video/x-matroska"
            case "m4v": return "video/x-m4v"
            default: return "video/mp4"
            }
            
        case .audio:
            switch fileExtension {
            case "mp3": return "audio/mpeg"
            case "m4a": return "audio/mp4"
            case "wav": return "audio/wav"
            case "aac": return "audio/aac"
            case "flac": return "audio/flac"
            default: return "audio/mpeg"
            }
            
        case .other:
            return "application/octet-stream"
        }
    }
    
    // MARK: - Delete File
    
    /// Xóa file từ Supabase Storage
    /// - Parameter fileURL: Public URL của file
    func deleteFile(fileURL: String) async throws {
        // Extract file name từ URL
        guard let fileName = fileURL.components(separatedBy: "/").last else {
            throw StorageError.invalidURL
        }
        
        let deleteURL = "\(AppConfig.supabaseURL)/storage/v1/object/\(bucketName)/\(fileName)"
        
        guard let url = URL(string: deleteURL) else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.uploadFailed
        }
        
        print("✅ File deleted successfully")
    }
}

