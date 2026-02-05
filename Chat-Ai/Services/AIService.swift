//
//  AIService.swift
//  Chat-Ai
//
//  Service để gọi API AI (Gemini, Groq hoặc OpenAI)
//

import Foundation

// Actor: đảm bảo thread-safe
actor AIService {
    
    static let shared = AIService()
    
    private init() {}
    
    /// Gửi tin nhắn đến AI và nhận phản hồi
    /// - Parameters:
    ///   - messages: Mảng các message trong conversation (để AI có context)
    ///   - image: Image data (not supported)
    /// - Returns: Nội dung phản hồi từ AI
    func sendMessage(messages: [Message], image: Data? = nil) async throws -> String {
        // ⚠️ Image không được hỗ trợ
        if image != nil {
            throw AIError.imageNotSupported
        }
        
        // ✅ Dùng Chat API mới
        return try await sendToChatAPI(messages: messages)
    }
    
    // MARK: - Chat API
    
    /// Gửi message đến Chat API mới
    /// - Parameter messages: Mảng các message trong conversation
    /// - Returns: Nội dung phản hồi từ AI
    /// - Note: Messages phải alternate: user, assistant, user, assistant...
    ///         Message cuối cùng phải là user message (current_user_msg)
    private func sendToChatAPI(messages: [Message]) async throws -> String {
        // Lấy user_id từ AuthService
        guard let currentUser = await AuthService.shared.getCurrentUser() else {
            throw AIError.requestFailed
        }
        let userId = currentUser.id.uuidString
        
        // Tạo URL cho Chat API (dùng cùng base URL với transcribe API)
        guard let url = URL(string: "\(AppConfig.transcribeAPIURL)/chat") else {
            throw AIError.invalidURL
        }
        
        // Chuyển đổi Message model sang format của API: array of strings (alternating user/assistant)
        // Format theo spec: [user_msg1, assistant_msg1, user_msg2, assistant_msg2, ..., current_user_msg]
        // Messages phải alternate: user, assistant, user, assistant...
        // Message cuối cùng phải là user message
        var messagesArray: [String] = []
        
        // Kiểm tra và đảm bảo messages alternate đúng và message cuối cùng là user
        var adjustedMessages = messages
        
        // Kiểm tra message cuối cùng có phải là user không
        if let lastMessage = adjustedMessages.last, lastMessage.role != .user {
            print("test log log10 : ⚠️ Last message is not user (role: \(lastMessage.role.rawValue)), API expects current_user_msg to be user")
        }
        
        // Kiểm tra message đầu tiên
        if let firstMessage = adjustedMessages.first {
            print("test log log10 : First message role: \(firstMessage.role.rawValue)")
        }
        
        // Chuyển đổi messages theo đúng thứ tự alternating
        for message in adjustedMessages {
            messagesArray.append(message.content)
        }
        
        print("test log log10 : ========== SENDING TO CHAT API ==========")
        print("test log log10 : API URL: \(url.absoluteString)")
        print("test log log10 : User ID: \(userId)")
        print("test log log10 : Total messages: \(messagesArray.count)")
        print("test log log10 : Expected format: [user_msg1, assistant_msg1, user_msg2, assistant_msg2, ..., current_user_msg]")
        for (index, content) in messagesArray.enumerated() {
            let contentPreview = content.count > 100 ? String(content.prefix(100)) + "..." : content
            // Log actual role từ Message object để debug
            let actualRole = index < adjustedMessages.count ? adjustedMessages[index].role.rawValue : "unknown"
            let expectedRole = index % 2 == 0 ? "user" : "assistant" // Even index = user, odd = assistant
            print("test log log10 :   [\(index + 1)] role=\(actualRole) (expected: \(expectedRole)), content_length=\(content.count), preview=\"\(contentPreview)\"")
        }
        
        // Tạo request body theo format của Chat API (chỉ có user_id và messages)
        let requestBody: [String: Any] = [
            "user_id": userId,
            "messages": messagesArray
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Log request body size
        print("test log log10 : Request body size: \(jsonData.count) bytes")
        if let requestString = String(data: jsonData, encoding: .utf8) {
            let previewLength = min(500, requestString.count)
            print("test log log10 : Request body preview (first \(previewLength) chars): \(String(requestString.prefix(previewLength)))")
        }
        print("test log log10 : =========================================")
        
        // Tạo request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Gọi API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Kiểm tra response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.requestFailed
        }
        
        print("test log log10 : HTTP status code: \(httpResponse.statusCode)")
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorString = String(data: data, encoding: .utf8) {
                print("test log log10 : Error response: \(errorString)")
            }
            throw AIError.requestFailed
        }
        
        // Parse response JSON theo format mới: { "success": true, "response": "string", "message": "string" }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool,
              success == true,
              let responseText = json["response"] as? String else {
            print("test log log10 : Invalid response format")
            if let rawString = String(data: data, encoding: .utf8) {
                print("test log log10 : Raw response: \(rawString)")
            }
            throw AIError.invalidResponse
        }
        
        print("test log log10 : ✅ Chat API response received, length: \(responseText.count) characters")
        return responseText
    }
    
    // MARK: - OpenAI API
    
    /// Gửi message đến OpenAI API
    private func sendToOpenAI(messages: [Message]) async throws -> String {
        guard let url = URL(string: AppConfig.openaiAPIURL) else {
            throw AIError.invalidURL
        }
        
        // Chuyển đổi Message model sang format của API
        let apiMessages = messages.map { message in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        
        // Tạo request body theo format của OpenAI API
        let requestBody: [String: Any] = [
            "model": AppConfig.openaiModel,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 1024
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Tạo request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.aiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Gọi API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Kiểm tra response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.requestFailed
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw AIError.requestFailed
        }
        
        // Parse response JSON (format giống Groq)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content
    }
}

// MARK: - Error Types

/// Các loại lỗi có thể xảy ra khi làm việc với AI API
enum AIError: LocalizedError {
    case missingAPIKey       // Chưa có API key
    case invalidURL          // URL không hợp lệ
    case requestFailed       // Request thất bại
    case invalidResponse     // Response không đúng format
    case imageNotSupported   // Không hỗ trợ xử lý ảnh
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "⚠️ No API key. Please add API key to AppConfig.swift"
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Cannot connect to AI service"
        case .invalidResponse:
            return "Invalid response from AI"
        case .imageNotSupported:
            return "⚠️ Groq doesn't support image processing. Please send text only."
        }
    }
}

