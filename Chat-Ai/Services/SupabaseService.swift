//
//  SupabaseService.swift
//  Chat-Ai
//
//  Service để kết nối và thao tác với Supabase database
//

import Foundation

// Actor: đảm bảo thread-safe khi làm việc với async/await
actor SupabaseService {
    
    // Singleton pattern: chỉ có 1 instance duy nhất trong app
    static let shared = SupabaseService()
    
    private init() {}
    
    // MARK: - Helper Methods
    
    /// Tạo authenticated request với access token
    /// - Note: Token được tự động refresh bởi AuthService (background task), không cần check mỗi request
    private func createAuthenticatedRequest(url: URL, method: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Lấy access token từ AuthService (đã được auto-refresh bởi background task)
        if let accessToken = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            // Fallback: Dùng anon key nếu chưa đăng nhập
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    // MARK: - Conversations Methods
    
    /// Lấy tất cả conversations của user hiện tại
    /// - Returns: Mảng các Conversation, sắp xếp theo thời gian cập nhật mới nhất
    func fetchConversations() async throws -> [Conversation] {
        // Tạo URL để gọi API Supabase
        // RLS sẽ tự động filter theo user_id từ auth token
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/conversations?order=updated_at.desc") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo authenticated request
        var request = try await createAuthenticatedRequest(url: url, method: "GET")
        
        // ✅ Tăng timeout để tránh bị cancel
        request.timeoutInterval = 30 // 30 seconds
        
        do {
            // Gọi API và parse response
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Kiểm tra response có thành công không (status code 200-299)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.requestFailed
            }
            
            // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
            if httpResponse.statusCode == 401 {
                print("❌ 401 Unauthorized - Token hết hạn")
                throw SupabaseError.unauthorized
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Supabase error: Status \(httpResponse.statusCode)")
                throw SupabaseError.requestFailed
            }
            
            // Decode JSON thành array của Conversation
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // Parse date format ISO 8601
            let conversations = try decoder.decode([Conversation].self, from: data)
            
            return conversations
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // ⚠️ Request bị cancel → Throw CancellationError để ViewModel xử lý
            print("⚠️ Request cancelled")
            throw CancellationError()
        }
    }
    
    /// Tạo một conversation mới
    /// - Parameter title: Tiêu đề của conversation
    /// - Returns: Conversation vừa tạo
    func createConversation(title: String) async throws -> Conversation {
        let userId = AppConfig.getCurrentUserId()
        
        // Tạo conversation object mới
        let newConversation = Conversation(
            userId: userId,
            title: title
        )
        
        // URL để insert vào table conversations
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/conversations") else {
            throw SupabaseError.invalidURL
        }
        
        // Encode conversation thành JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(newConversation)
        
        // Tạo authenticated POST request
        var request = try await createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer") // Trả về object vừa tạo
        request.httpBody = jsonData
        
        // Gọi API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Debug: In ra lỗi chi tiết
            print("❌ Supabase Error - Status Code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error Response: \(errorString)")
            }
            throw SupabaseError.requestFailed
        }
        
        // Parse response để lấy conversation vừa tạo
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let conversations = try decoder.decode([Conversation].self, from: data)
        
        guard let createdConversation = conversations.first else {
            throw SupabaseError.decodingFailed
        }
        
        return createdConversation
    }
    
    /// Xóa một conversation
    /// - Parameter id: ID của conversation cần xóa
    func deleteConversation(id: UUID) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/conversations?id=eq.\(id.uuidString)") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo authenticated DELETE request
        let request = try await createAuthenticatedRequest(url: url, method: "DELETE")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }
    
    /// Xóa tất cả conversations của user hiện tại
    func deleteAllConversations() async throws {
        let userId = AppConfig.getCurrentUserId()
        
        // Filter theo user_id
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/conversations?user_id=eq.\(userId.uuidString)") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo authenticated DELETE request
        let request = try await createAuthenticatedRequest(url: url, method: "DELETE")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Debug: In ra lỗi chi tiết
            print("❌ Delete All Conversations Error - Status Code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error Response: \(errorString)")
            }
            throw SupabaseError.requestFailed
        }
        
        print("✅ Deleted all conversations for user \(userId)")
    }
    
    // MARK: - Messages Methods
    
    /// Lấy tất cả messages của một conversation
    /// - Parameter conversationId: ID của conversation
    /// - Returns: Mảng các Message, sắp xếp theo thời gian tạo
    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/messages?conversation_id=eq.\(conversationId.uuidString)&order=created_at.asc") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo authenticated GET request
        let request = try await createAuthenticatedRequest(url: url, method: "GET")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messages = try decoder.decode([Message].self, from: data)
        
        return messages
    }
    
    /// Tạo một message mới
    /// - Parameters:
    ///   - conversationId: ID của conversation chứa message
    ///   - role: Vai trò (user hoặc assistant)
    ///   - content: Nội dung message
    ///   - fileUrl: URL của file đính kèm (optional)
    ///   - fileName: Tên file (optional)
    ///   - fileType: Loại file (optional)
    ///   - fileSize: Kích thước file (optional)
    /// - Returns: Message vừa tạo
    func createMessage(
        conversationId: UUID,
        role: Message.MessageRole,
        content: String,
        fileUrl: String? = nil,
        fileName: String? = nil,
        fileType: String? = nil,
        fileSize: Int? = nil
    ) async throws -> Message {
        let newMessage = Message(
            conversationId: conversationId,
            role: role,
            content: content,
            fileUrl: fileUrl,
            fileName: fileName,
            fileType: fileType,
            fileSize: fileSize
        )
        
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/messages") else {
            throw SupabaseError.invalidURL
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(newMessage)
        
        // Tạo authenticated POST request
        var request = try await createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messages = try decoder.decode([Message].self, from: data)
        
        guard let createdMessage = messages.first else {
            throw SupabaseError.decodingFailed
        }
        
        return createdMessage
    }
    
    /// Cập nhật updated_at của conversation (khi có message mới)
    /// - Parameter conversationId: ID của conversation cần cập nhật
    func updateConversationTimestamp(conversationId: UUID) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString)") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo JSON body với updated_at mới
        let updateData: [String: Any] = [
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }
    
    /// Cập nhật title của conversation
    /// - Parameters:
    ///   - conversationId: ID của conversation
    ///   - newTitle: Tên mới
    func updateConversationTitle(conversationId: UUID, newTitle: String) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString)") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo JSON body với title mới
        let updateData: [String: Any] = [
            "title": newTitle,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)
        
        // Tạo authenticated PATCH request
        var request = try await createAuthenticatedRequest(url: url, method: "PATCH")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Update title error: Status \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error Response: \(errorString)")
            }
            throw SupabaseError.requestFailed
        }
        
        print("✅ Updated conversation title to: \(newTitle)")
    }
    
    /// Xóa tất cả messages trong một conversation
    /// - Parameter conversationId: ID của conversation
    func deleteAllMessages(conversationId: UUID) async throws {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/messages?conversation_id=eq.\(conversationId.uuidString)") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo authenticated DELETE request
        let request = try await createAuthenticatedRequest(url: url, method: "DELETE")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            print("❌ 401 Unauthorized - Token hết hạn")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        print("✅ Deleted all messages in conversation \(conversationId)")
    }
}

// MARK: - Error Types

/// Các loại lỗi có thể xảy ra khi làm việc với Supabase
enum SupabaseError: LocalizedError, Equatable {
    case invalidURL          // URL không hợp lệ
    case requestFailed       // Request thất bại (lỗi network hoặc server)
    case decodingFailed      // Không parse được JSON
    case unauthorized        // Token hết hạn hoặc không hợp lệ (401)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Cannot connect to server"
        case .decodingFailed:
            return "Cannot read data from server"
        case .unauthorized:
            return "Session expired. Please login again."
        }
    }
}

