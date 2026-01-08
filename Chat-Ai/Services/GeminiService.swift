//
//  GeminiService.swift
//  Chat-Ai
//
//  Service để gọi Google Gemini API (hỗ trợ text + image)
//

import Foundation

// MARK: - GeminiError

enum GeminiError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(statusCode: Int, message: String)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "⚠️ Chưa có Gemini API key"
        case .invalidURL:
            return "URL không hợp lệ"
        case .requestFailed(let error):
            return "Yêu cầu API thất bại: \(error.localizedDescription)"
        case .invalidResponse:
            return "Phản hồi từ Gemini không hợp lệ"
        case .decodingFailed(let error):
            return "Không thể giải mã phản hồi: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Lỗi server Gemini (\(statusCode)): \(message)"
        case .unknownError(let error):
            return "Lỗi không xác định: \(error.localizedDescription)"
        }
    }
}

// MARK: - GeminiService

actor GeminiService {
    
    static let shared = GeminiService()
    
    private init() {}
    
    // MARK: - Configuration
    
    // Gemini 2.5 Flash - Model mới nhất (June 2025), hỗ trợ multimodal
    private let apiURL = "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent"
    
    // MARK: - Send Message with Image
    
    /// Gửi message có ảnh đến Gemini
    /// - Parameters:
    ///   - text: Nội dung text
    ///   - imageData: Data của ảnh
    /// - Returns: Phản hồi từ Gemini
    func sendMessageWithImage(text: String, imageData: Data) async throws -> String {
        guard !AppConfig.aiAPIKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }
        
        // Convert image data to base64
        let base64Image = imageData.base64EncodedString()
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": text.isEmpty ? "Hãy mô tả ảnh này" : text
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        return try await sendRequest(body: requestBody)
    }
    
    // MARK: - Send Text Only
    
    /// Gửi message chỉ có text đến Gemini
    /// - Parameter text: Nội dung text
    /// - Returns: Phản hồi từ Gemini
    func sendMessage(text: String) async throws -> String {
        guard !AppConfig.aiAPIKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": text
                        ]
                    ]
                ]
            ]
        ]
        
        return try await sendRequest(body: requestBody)
    }
    
    // MARK: - Send Request
    
    /// Gửi request đến Gemini API
    private func sendRequest(body: [String: Any]) async throws -> String {
        // Tạo URL với API key
        guard let url = URL(string: "\(apiURL)?key=\(AppConfig.aiAPIKey)") else {
            throw GeminiError.invalidURL
        }
        
        // Tạo request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert body to JSON
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Gọi API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Kiểm tra response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.decodingFailed(NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
        }
        
        return text
    }
}

