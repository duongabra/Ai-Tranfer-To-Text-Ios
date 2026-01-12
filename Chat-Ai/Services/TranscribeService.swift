//
//  TranscribeService.swift
//  Chat-Ai
//
//  Service để transcribe audio/video thành text
//

import Foundation

// MARK: - Transcribe Response Model

struct TranscribeResponse: Codable {
    let success: Bool
    let contextId: String?
    let title: String?
    let summary: String?
    let transcription: String
    let durationSeconds: Int?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case contextId = "context_id"
        case title
        case summary
        case transcription
        case durationSeconds = "duration_seconds"
        case message
    }
}

// MARK: - Transcribe Service

actor TranscribeService {
    
    static let shared = TranscribeService()
    
    private init() {}
    
    /// Transcribe audio file thành text
    /// - Parameters:
    ///   - audioData: Data của audio file
    ///   - fileName: Tên file (cần có extension: .m4a, .mp3, .wav, .ogg, .oga, .opus)
    ///   - userId: ID của user
    /// - Returns: Text transcription
    func transcribeAudio(audioData: Data, fileName: String, userId: Int) async throws -> String {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/audio")!
        
        // Tạo multipart/form-data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Tạo body
        var body = Data()
        
        // Add user_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/\(fileName.components(separatedBy: ".").last ?? "mp3")\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Call API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscribeError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Transcribe Audio Error - Status: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error Response: \(errorString)")
            }
            throw TranscribeError.requestFailed
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
        
        guard transcribeResponse.success else {
            throw TranscribeError.transcriptionFailed
        }
        
        print("✅ Audio transcribed successfully")
        return transcribeResponse.transcription
    }
    
    /// Transcribe video URL (YouTube, etc.) thành text
    /// - Parameters:
    ///   - videoURL: URL của video
    ///   - userId: ID của user
    /// - Returns: Text transcription
    func transcribeVideoURL(videoURL: String, userId: Int) async throws -> String {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/video-url")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "user_id": userId,
            "video_url": videoURL
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Call API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscribeError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Transcribe Video Error - Status: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error Response: \(errorString)")
            }
            throw TranscribeError.requestFailed
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
        
        guard transcribeResponse.success else {
            throw TranscribeError.transcriptionFailed
        }
        
        print("✅ Video transcribed successfully")
        return transcribeResponse.transcription
    }
}

// MARK: - Error Types

enum TranscribeError: LocalizedError {
    case requestFailed
    case transcriptionFailed
    case invalidFileFormat
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Không thể kết nối đến server transcribe"
        case .transcriptionFailed:
            return "Không thể transcribe audio/video"
        case .invalidFileFormat:
            return "Định dạng file không được hỗ trợ"
        }
    }
}

