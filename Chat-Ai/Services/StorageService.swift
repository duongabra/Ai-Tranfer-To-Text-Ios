//
//  StorageService.swift
//  Chat-Ai
//
//  Service để upload/download file từ Supabase Storage
//

import Foundation

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
            return "Invalid URL"
        case .uploadFailed:
            return "Cannot upload file"
        case .fileTooLarge(let maxSize):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB]
            formatter.countStyle = .file
            let maxSizeString = formatter.string(fromByteCount: Int64(maxSize))
            return "File too large. Maximum size: \(maxSizeString)"
        case .unsupportedFileType:
            return "File type not supported"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
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
        .audio: 20 * 1024 * 1024,  // 20MB
    ]

    // MARK: - Upload File

    /// Upload file lên Supabase Storage
    /// - Parameters:
    ///   - data: Data của file
    ///   - fileName: Tên file
    ///   - fileType: Loại file
    ///   - customMaxSize: Max file size tùy chỉnh (optional, nếu nil thì dùng default)
    /// - Returns: Public URL của file đã upload
    func uploadFile(
        data: Data, fileName: String, fileType: FileAttachment.FileType, customMaxSize: Int? = nil
    ) async throws -> String {
        // Kiểm tra kích thước file
        let maxSize: Int
        if let customMaxSize = customMaxSize {
            maxSize = customMaxSize
        } else if let defaultMaxSize = maxFileSize[fileType] {
            maxSize = defaultMaxSize
        } else {
            maxSize = 10 * 1024 * 1024  // Default 10MB
        }

        if data.count > maxSize {
            throw StorageError.fileTooLarge(maxSize: maxSize)
        }

        // Sanitize file name: loại bỏ ký tự đặc biệt và encode URL
        let sanitizedFileName = sanitizeFileName(fileName)

        // Tạo unique file name (để tránh trùng)
        let uniqueFileName = "\(UUID().uuidString)_\(sanitizedFileName)"

        // Tạo URL để upload - encode fileName để tránh lỗi với ký tự đặc biệt
        let encodedFileName =
            uniqueFileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? uniqueFileName
        let uploadURL =
            "\(AppConfig.supabaseURL)/storage/v1/object/\(bucketName)/\(encodedFileName)"

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
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")  // ✅ Dùng access token

        // Set Content-Type dựa vào file type
        let contentType = getContentType(for: fileName, fileType: fileType)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        request.httpBody = data

        // Upload file
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            print(
                "❌ Upload failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
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

    // MARK: - Sanitize File Name

    /// Sanitize file name để loại bỏ ký tự đặc biệt và ký tự không hợp lệ cho URL
    /// - Parameter fileName: Tên file gốc
    /// - Returns: Tên file đã được sanitize (chỉ ASCII, không có dấu)
    private func sanitizeFileName(_ fileName: String) -> String {
        // Lấy extension trước
        let fileExtension = (fileName as NSString).pathExtension
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension

        // Bước 1: Convert Unicode về ASCII không dấu (ví dụ: "PHÙNG" → "PHUNG")
        let mutableString = NSMutableString(string: nameWithoutExtension) as CFMutableString
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripCombiningMarks, false)
        let asciiString = mutableString as String

        // Bước 2: Chỉ giữ lại ASCII alphanumeric và một số ký tự đặc biệt an toàn
        // Loại bỏ em dash (–) và các ký tự đặc biệt khác, chỉ giữ hyphen (-)
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let sanitized =
            asciiString
            .components(separatedBy: allowedCharacters.inverted)
            .joined(separator: "_")
            .replacingOccurrences(of: "__", with: "_")  // Loại bỏ double underscore
            .replacingOccurrences(of: "_-", with: "_")  // Loại bỏ underscore-hyphen
            .replacingOccurrences(of: "-_", with: "_")  // Loại bỏ hyphen-underscore
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))  // Loại bỏ underscore/hyphen ở đầu/cuối

        // Giới hạn độ dài tên file (tránh quá dài)
        let maxLength = 100
        let truncated =
            sanitized.count > maxLength ? String(sanitized.prefix(maxLength)) : sanitized

        // Kết hợp lại với extension (extension cũng cần sanitize)
        let sanitizedExtension = fileExtension.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789").inverted)
            .joined()

        if sanitizedExtension.isEmpty {
            return truncated.isEmpty ? "file" : truncated
        } else {
            return "\(truncated.isEmpty ? "file" : truncated).\(sanitizedExtension)"
        }
    }

    // MARK: - Get Public URL

    /// Lấy public URL của file
    /// - Parameter fileName: Tên file trong storage
    /// - Returns: Public URL
    private func getPublicURL(for fileName: String) -> String {
        // Encode fileName để tránh lỗi với ký tự đặc biệt
        let encodedFileName =
            fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        return "\(AppConfig.supabaseURL)/storage/v1/object/public/\(bucketName)/\(encodedFileName)"
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
            (200...299).contains(httpResponse.statusCode)
        else {
            throw StorageError.uploadFailed
        }

        print("✅ File deleted successfully")
    }
}
