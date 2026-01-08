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
    /// - Parameter messages: Mảng các message trong conversation (để AI có context)
    /// - Returns: Nội dung phản hồi từ AI
    func sendMessage(messages: [Message], image: Data? = nil) async throws -> String {
        // Kiểm tra xem đã có API key chưa
        guard !AppConfig.aiAPIKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        // ⚠️ Groq không hỗ trợ xử lý ảnh
        if image != nil {
            throw AIError.imageNotSupported
        }
        
        // ✅ Dùng Groq (chỉ hỗ trợ text)
        return try await sendToGroq(messages: messages)
    }
    
    // MARK: - Groq API
    
    /// Gửi message đến Groq API
    private func sendToGroq(messages: [Message]) async throws -> String {
        guard let url = URL(string: AppConfig.groqAPIURL) else {
            throw AIError.invalidURL
        }
        
        // Chuyển đổi Message model sang format của API
        let apiMessages = messages.map { message in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        
        // Tạo request body theo format của Groq API
        let requestBody: [String: Any] = [
            "model": AppConfig.groqModel,
            "messages": apiMessages,
            "temperature": 0.7,      // Độ "sáng tạo" của AI (0.0 - 2.0)
            "max_tokens": 1024,      // Số token tối đa trong response
            "top_p": 1,
            "stream": false          // Không dùng streaming (nhận response một lần)
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
        
        // Nếu lỗi, in ra để debug
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Groq API Error: \(errorString)")
            }
            throw AIError.requestFailed
        }
        
        // Parse response JSON
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content
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
                print("❌ OpenAI API Error: \(errorString)")
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
            return "⚠️ Chưa có API key. Vui lòng thêm API key vào file AppConfig.swift"
        case .invalidURL:
            return "URL không hợp lệ"
        case .requestFailed:
            return "Không thể kết nối đến AI service"
        case .invalidResponse:
            return "Phản hồi từ AI không hợp lệ"
        case .imageNotSupported:
            return "⚠️ Groq không hỗ trợ xử lý ảnh. Vui lòng chỉ gửi text."
        }
    }
}

