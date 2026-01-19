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
                throw SupabaseError.unauthorized
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw SupabaseError.requestFailed
            }
            
            // Decode JSON thành array của Conversation
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // Parse date format ISO 8601
            let conversations = try decoder.decode([Conversation].self, from: data)
            
            return conversations
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // ⚠️ Request bị cancel → Throw CancellationError để ViewModel xử lý
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
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Debug: In ra lỗi chi tiết
            if let errorString = String(data: data, encoding: .utf8) {
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
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Debug: In ra lỗi chi tiết
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw SupabaseError.requestFailed
        }
        
    }
    
    // MARK: - Messages Methods
    
    /// Lấy tất cả messages của một conversation
    /// - Parameter conversationId: ID của conversation
    /// - Returns: Mảng các Message, sắp xếp theo thời gian tạo
    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        print("📥 [SupabaseService] fetchMessages() - ConversationId: \(conversationId)")
        
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/messages?conversation_id=eq.\(conversationId.uuidString)&order=created_at.asc") else {
            throw SupabaseError.invalidURL
        }
        
        // Tạo authenticated GET request
        let request = try await createAuthenticatedRequest(url: url, method: "GET")
        
        print("📥 [SupabaseService] Đang fetch messages từ DB...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        print("📥 [SupabaseService] HTTP Status Code: \(httpResponse.statusCode)")
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("📥 [SupabaseService] Error response: \(errorString)")
            }
            throw SupabaseError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messages = try decoder.decode([Message].self, from: data)
        
        print("📥 [SupabaseService] Đã fetch \(messages.count) messages từ DB")
        for (index, message) in messages.enumerated() {
            print("📥 [SupabaseService] Message \(index):")
            print("   - Role: \(message.role.rawValue)")
            print("   - ID: \(message.id)")
            print("   - Content: \(message.content.prefix(50))...")
            print("   - File URL: \(message.fileUrl ?? "nil")")
            print("   - File Name: \(message.fileName ?? "nil")")
            print("   - File Type: \(message.fileType ?? "nil")")
            if message.fileType == "other" {
                print("   ✅ This is a transcription file (fileType=other)")
            }
        }
        
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
        print("💾 [SupabaseService] createMessage() - Role nhận được: \(role.rawValue)")
        print("💾 [SupabaseService] createMessage() - Content length: \(content.count)")
        print("💾 [SupabaseService] createMessage() - ConversationId: \(conversationId)")
        
        let newMessage = Message(
            conversationId: conversationId,
            role: role,
            content: content,
            fileUrl: fileUrl,
            fileName: fileName,
            fileType: fileType,
            fileSize: fileSize
        )
        
        print("💾 [SupabaseService] newMessage role: \(newMessage.role.rawValue)")
        
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/messages") else {
            throw SupabaseError.invalidURL
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(newMessage)
        
        // Debug: In ra JSON để kiểm tra role
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("💾 [SupabaseService] JSON data gửi lên DB: \(jsonString)")
        }
        
        // Tạo authenticated POST request
        var request = try await createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        
        print("💾 [SupabaseService] Đang gửi request lên DB...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        print("💾 [SupabaseService] HTTP Status Code: \(httpResponse.statusCode)")
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("💾 [SupabaseService] Error response: \(errorString)")
            }
            throw SupabaseError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messages = try decoder.decode([Message].self, from: data)
        
        guard let createdMessage = messages.first else {
            throw SupabaseError.decodingFailed
        }
        
        print("💾 [SupabaseService] Message đã lưu vào DB thành công")
        print("💾 [SupabaseService] Created message role từ DB: \(createdMessage.role.rawValue)")
        print("💾 [SupabaseService] Created message id: \(createdMessage.id)")
        
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
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw SupabaseError.requestFailed
        }
        
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
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
    }
    
    // MARK: - User Profile Methods
    
    /// Xóa user profile từ database
    /// - Parameter userId: ID của user cần xóa profile
    func deleteUserProfile(userId: UUID) async throws {
        // Sử dụng ilike và lowercase để tránh case sensitivity issues
        let userIdLower = userId.uuidString.lowercased()
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles?user_id=ilike.\(userIdLower)") else {
            throw SupabaseError.invalidURL
        }
        
        let request = try await createAuthenticatedRequest(url: url, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        // ✅ Kiểm tra 401 Unauthorized → Token hết hạn
        if httpResponse.statusCode == 401 {
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }
    
    /// Lấy user profile từ database
    /// - Parameter userId: ID của user
    /// - Returns: Dictionary chứa firstName, lastName, avatarURL hoặc nil nếu không có
    func getUserProfile(userId: UUID) async throws -> [String: String?]? {
        // Sử dụng ilike (case-insensitive) hoặc lower() để tránh case sensitivity issues
        // PostgreSQL TEXT comparison là case-sensitive, nhưng UUID thường được lưu lowercase
        let userIdLower = userId.uuidString.lowercased()
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles?user_id=ilike.\(userIdLower)") else {
            throw SupabaseError.invalidURL
        }
        
        let request = try await createAuthenticatedRequest(url: url, method: "GET")
        
        print("🔍 [SupabaseService] Getting user profile...")
        print("   - User ID: \(userId.uuidString)")
        print("   - URL: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [SupabaseService] Invalid HTTP response when getting profile")
            throw SupabaseError.requestFailed
        }
        
        print("🔍 [SupabaseService] Get profile response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            print("❌ [SupabaseService] Unauthorized when getting profile")
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [SupabaseService] Failed to get profile:")
            print("   - Status Code: \(httpResponse.statusCode)")
            print("   - Error: \(errorString)")
            throw SupabaseError.requestFailed
        }
        
        // Parse response
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let profile = jsonArray.first {
            print("✅ [SupabaseService] Profile found: \(profile)")
            let result = [
                "first_name": profile["first_name"] as? String,
                "last_name": profile["last_name"] as? String,
                "avatar_url": profile["avatar_url"] as? String
            ]
            return result
        }
        
        print("ℹ️ [SupabaseService] No profile found (empty array)")
        return nil
    }
    
    /// Đảm bảo user profile tồn tại trong database (tạo mới nếu chưa có)
    /// - Parameters:
    ///   - userId: ID của user
    ///   - avatarURL: URL của avatar (optional)
    func ensureUserProfileExists(userId: UUID, avatarURL: String? = nil) async throws {
        // Kiểm tra xem profile đã tồn tại chưa
        let existingProfile = try? await getUserProfile(userId: userId)
        
        if existingProfile == nil {
            // Chưa có profile → tạo mới
            print("💾 [SupabaseService] User profile not found, creating new profile for user: \(userId.uuidString)")
            
            // Thử gọi RPC function trước (nếu có)
            // Sử dụng lowercase để đảm bảo consistency
            if let rpcResult = try? await callRPCFunction(functionName: "create_user_profile_if_not_exists", params: ["p_user_id": userId.uuidString.lowercased()]) {
                print("✅ [SupabaseService] User profile created via RPC function")
                // Nếu có avatarURL, update sau
                if let avatarURL = avatarURL {
                    try await saveUserProfile(
                        userId: userId,
                        firstName: nil,
                        lastName: nil,
                        avatarURL: avatarURL
                    )
                }
            } else {
                // Fallback: dùng cách cũ (INSERT trực tiếp)
                try await saveUserProfile(
                    userId: userId,
                    firstName: nil,
                    lastName: nil,
                    avatarURL: avatarURL
                )
                print("✅ [SupabaseService] User profile created successfully")
            }
        } else {
            print("ℹ️ [SupabaseService] User profile already exists for user: \(userId.uuidString)")
        }
    }
    
    /// Gọi RPC function trong Supabase
    /// - Parameters:
    ///   - functionName: Tên function
    ///   - params: Parameters dưới dạng dictionary
    /// - Returns: Response data hoặc nil nếu lỗi
    private func callRPCFunction(functionName: String, params: [String: Any]) async throws -> Data? {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/rpc/\(functionName)") else {
            throw SupabaseError.invalidURL
        }
        
        var request = try await createAuthenticatedRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        if httpResponse.statusCode == 401 {
            throw SupabaseError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        
        return data
    }
    
    /// Lưu hoặc cập nhật user profile vào database
    /// - Parameters:
    ///   - userId: ID của user
    ///   - firstName: Tên
    ///   - lastName: Họ
    ///   - avatarURL: URL của avatar (optional)
    func saveUserProfile(userId: UUID, firstName: String?, lastName: String?, avatarURL: String?) async throws {
        // Kiểm tra xem profile đã tồn tại chưa
        let existingProfile = try? await getUserProfile(userId: userId)
        
        print("💾 [SupabaseService] saveUserProfile called:")
        print("   - User ID: \(userId.uuidString)")
        print("   - Existing profile: \(existingProfile != nil ? "Found" : "Not found")")
        
        // Chỉ thêm các field có giá trị (không gửi nil)
        // Sử dụng lowercase để đảm bảo consistency với DB
        var profileData: [String: Any] = [
            "user_id": userId.uuidString.lowercased(),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let firstName = firstName, !firstName.isEmpty {
            profileData["first_name"] = firstName
        } else if firstName == nil && existingProfile == nil {
            // Nếu là insert mới và firstName là nil, không thêm vào
        } else if firstName != nil {
            // Nếu firstName là empty string, set null để xóa
            profileData["first_name"] = NSNull()
        }
        
        if let lastName = lastName, !lastName.isEmpty {
            profileData["last_name"] = lastName
        } else if lastName == nil && existingProfile == nil {
            // Nếu là insert mới và lastName là nil, không thêm vào
        } else if lastName != nil {
            // Nếu lastName là empty string, set null để xóa
            profileData["last_name"] = NSNull()
        }
        
        if let avatarURL = avatarURL {
            profileData["avatar_url"] = avatarURL
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: profileData)
        
        if existingProfile != nil {
            // Update existing profile
            // Sử dụng ilike để tránh case sensitivity issues
            let userIdLower = userId.uuidString.lowercased()
            guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles?user_id=ilike.\(userIdLower)") else {
                throw SupabaseError.invalidURL
            }
            
            var request = try await createAuthenticatedRequest(url: url, method: "PATCH")
            request.httpBody = jsonData
            
            print("💾 [SupabaseService] Updating user profile...")
            print("   - User ID: \(userId.uuidString)")
            print("   - URL: \(url)")
            
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                print("❌ [SupabaseService] Network error: \(error.localizedDescription)")
                throw SupabaseError.requestFailed
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [SupabaseService] Invalid HTTP response")
                throw SupabaseError.requestFailed
            }
            
            print("💾 [SupabaseService] Update response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                print("❌ [SupabaseService] Unauthorized - token expired")
                throw SupabaseError.unauthorized
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [SupabaseService] Failed to update profile:")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Error: \(errorString)")
                throw SupabaseError.requestFailed
            }
            
            print("✅ [SupabaseService] User profile updated successfully")
            
        } else {
            // Insert new profile
            print("💾 [SupabaseService] Creating new user profile...")
            print("   - User ID: \(userId.uuidString)")
            print("   - First Name: \(firstName ?? "nil")")
            print("   - Last Name: \(lastName ?? "nil")")
            print("   - Avatar URL: \(avatarURL ?? "nil")")
            print("   - Profile Data: \(profileData)")
            
            guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles") else {
                throw SupabaseError.invalidURL
            }
            
            var profileDataWithCreated = profileData
            profileDataWithCreated["created_at"] = ISO8601DateFormatter().string(from: Date())
            let insertData = try JSONSerialization.data(withJSONObject: profileDataWithCreated)
            
            // Log request data
            if let jsonString = String(data: insertData, encoding: .utf8) {
                print("💾 [SupabaseService] Insert data JSON: \(jsonString)")
            }
            
            var request = try await createAuthenticatedRequest(url: url, method: "POST")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = insertData
            
            // Debug: Kiểm tra xem có Authorization header không
            if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                let tokenPreview = authHeader.prefix(20) + "..."
                print("💾 [SupabaseService] Inserting user profile...")
                print("   - URL: \(url)")
                print("   - Authorization header: \(tokenPreview)")
            } else {
                print("⚠️ [SupabaseService] WARNING: No Authorization header found!")
            }
            
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                print("❌ [SupabaseService] Network error during insert: \(error.localizedDescription)")
                print("   - Error details: \(error)")
                throw SupabaseError.requestFailed
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [SupabaseService] Invalid HTTP response")
                throw SupabaseError.requestFailed
            }
            
            print("💾 [SupabaseService] Insert response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                print("❌ [SupabaseService] Unauthorized - token expired")
                throw SupabaseError.unauthorized
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [SupabaseService] Failed to insert profile:")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Error: \(errorString)")
                throw SupabaseError.requestFailed
            }
            
            print("✅ [SupabaseService] User profile created successfully")
        }
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

