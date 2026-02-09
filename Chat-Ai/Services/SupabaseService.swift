//
//  SupabaseService.swift
//  Chat-Ai
//
//  Service để kết nối và thao tác với Supabase (chỉ user profile cho Auth)
//

import Foundation

actor SupabaseService {

    static let shared = SupabaseService()

    private init() {}

    // MARK: - Helper Methods

    private func createAuthenticatedRequest(url: URL, method: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - User Profile Methods

    func deleteUserProfile(userId: UUID) async throws {
        let userIdLower = userId.uuidString.lowercased()
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles?user_id=ilike.\(userIdLower)") else {
            throw SupabaseError.invalidURL
        }

        let request = try await createAuthenticatedRequest(url: url, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }

        if httpResponse.statusCode == 401 {
            throw SupabaseError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }

    func getUserProfile(userId: UUID) async throws -> [String: String?]? {
        let userIdLower = userId.uuidString.lowercased()
        guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles?user_id=ilike.\(userIdLower)") else {
            throw SupabaseError.invalidURL
        }

        let request = try await createAuthenticatedRequest(url: url, method: "GET")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }

        if httpResponse.statusCode == 401 {
            throw SupabaseError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }

        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let profile = jsonArray.first {
            return [
                "first_name": profile["first_name"] as? String,
                "last_name": profile["last_name"] as? String,
                "avatar_url": profile["avatar_url"] as? String
            ]
        }

        return nil
    }

    func ensureUserProfileExists(userId: UUID, avatarURL: String? = nil) async throws {
        let existingProfile = try? await getUserProfile(userId: userId)

        if existingProfile == nil {
            if (try? await callRPCFunction(functionName: "create_user_profile_if_not_exists", params: ["p_user_id": userId.uuidString.lowercased()])) != nil {
                if let avatarURL = avatarURL {
                    try await saveUserProfile(
                        userId: userId,
                        firstName: nil,
                        lastName: nil,
                        avatarURL: avatarURL
                    )
                }
            } else {
                try await saveUserProfile(
                    userId: userId,
                    firstName: nil,
                    lastName: nil,
                    avatarURL: avatarURL
                )
            }
        }
    }

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

    func saveUserProfile(userId: UUID, firstName: String?, lastName: String?, avatarURL: String?) async throws {
        let existingProfile = try? await getUserProfile(userId: userId)

        var profileData: [String: Any] = [
            "user_id": userId.uuidString.lowercased(),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let firstName = firstName, !firstName.isEmpty {
            profileData["first_name"] = firstName
        } else if firstName == nil && existingProfile == nil {
        } else if firstName != nil {
            profileData["first_name"] = NSNull()
        }

        if let lastName = lastName, !lastName.isEmpty {
            profileData["last_name"] = lastName
        } else if lastName == nil && existingProfile == nil {
        } else if lastName != nil {
            profileData["last_name"] = NSNull()
        }

        if let avatarURL = avatarURL {
            profileData["avatar_url"] = avatarURL
        }

        let jsonData = try JSONSerialization.data(withJSONObject: profileData)

        if existingProfile != nil {
            let userIdLower = userId.uuidString.lowercased()
            guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles?user_id=ilike.\(userIdLower)") else {
                throw SupabaseError.invalidURL
            }

            var request = try await createAuthenticatedRequest(url: url, method: "PATCH")
            request.httpBody = jsonData

            let (_, response): (Data, URLResponse)
            do {
                (_, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw SupabaseError.requestFailed
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.requestFailed
            }

            if httpResponse.statusCode == 401 {
                throw SupabaseError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw SupabaseError.requestFailed
            }

        } else {
            guard let url = URL(string: "\(AppConfig.supabaseURL)/rest/v1/user_profiles") else {
                throw SupabaseError.invalidURL
            }

            var profileDataWithCreated = profileData
            profileDataWithCreated["created_at"] = ISO8601DateFormatter().string(from: Date())
            let insertData = try JSONSerialization.data(withJSONObject: profileDataWithCreated)

            var request = try await createAuthenticatedRequest(url: url, method: "POST")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = insertData

            let (_, response): (Data, URLResponse)
            do {
                (_, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw SupabaseError.requestFailed
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.requestFailed
            }

            if httpResponse.statusCode == 401 {
                throw SupabaseError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw SupabaseError.requestFailed
            }
        }
    }

    // MARK: - Storage (upload ảnh, trả về public URL)

    private static let storageBucket = "lipstick"

    /// Upload image data lên Supabase Storage, trả về public URL để preview / gửi BE sau.
    /// Bucket "lipstick" cần có policy cho phép insert (upload) — ví dụ: authenticated users.
    func uploadImageToStorage(userId: UUID, imageData: Data, fileExtension: String = "jpg") async throws -> String {
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let path = "\(userId.uuidString.lowercased())/\(fileName)"
        guard let url = URL(string: "\(AppConfig.supabaseURL)/storage/v1/object/\(Self.storageBucket)/\(path)") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("true", forHTTPHeaderField: "x-upsert")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SupabaseError.storageUploadFailed(message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.storageUploadFailed(message: "Invalid response")
        }
        if http.statusCode == 401 { throw SupabaseError.unauthorized }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SupabaseError.storageUploadFailed(message: "HTTP \(http.statusCode): \(message)")
        }

        let publicURL = "\(AppConfig.supabaseURL)/storage/v1/object/public/\(Self.storageBucket)/\(path)"
        return publicURL
    }

    // MARK: - Conversations / Messages (stubs – no backend tables in current setup)

    /// Fetches messages for a conversation. Stub returns empty array until messages table exists.
    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        return []
    }

    /// Deletes all conversations and messages for current user. No-op until conversations table exists.
    func deleteAllConversations() async throws {
        // No-op: no conversations table in current Supabase schema
    }
}

// MARK: - Error Types

enum SupabaseError: LocalizedError, Equatable {
    case invalidURL
    case requestFailed
    case decodingFailed
    case unauthorized
    case storageUploadFailed(message: String)

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
        case .storageUploadFailed(let message):
            return message
        }
    }
}
