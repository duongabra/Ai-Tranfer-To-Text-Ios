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
    let transcription: String  // S3 URL để download file
    let durationSeconds: Int?
    let message: String?       // Text transcription để hiển thị
    
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

// MARK: - Transcribe Result

/// Kết quả transcription chứa cả S3 URL và message text
struct TranscribeResult {
    let transcriptionURL: String  // S3 URL để download file
    let message: String           // Text transcription để hiển thị
    let contextId: String?
    let title: String?
    let summary: String?
    let durationSeconds: Int?
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
    /// - Returns: TranscribeResult chứa transcription URL (S3) và message text
    func transcribeAudio(audioData: Data, fileName: String, userId: Int) async throws -> TranscribeResult {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/audio-mobile")!
        
        print("🎵 [TranscribeService] Starting audio transcription...")
        print("   - Endpoint: \(url.absoluteString)")
        print("   - File name: \(fileName)")
        print("   - File size: \(audioData.count) bytes")
        print("   - User ID: \(userId)")
        
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
        
        // Log request details
        print("🎵 [TranscribeService] Request details:")
        print("   - Method: POST")
        print("   - Content-Type: multipart/form-data")
        print("   - Body size: \(body.count) bytes")
        
        // ✅ Tăng timeout cho transcription (video/audio có thể mất nhiều thời gian)
        request.timeoutInterval = 600 // 10 phút (600 giây)
        
        // Call API với error handling cho timeout
        do {
            print("🎵 [TranscribeService] Sending request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("🎵 [TranscribeService] Response received, size: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscribeError.requestFailed
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [TranscribeService] HTTP Error: \(httpResponse.statusCode)")
                    print("   - Raw response: \(errorString)")
                }
                throw TranscribeError.requestFailed
            }
            
            // Log raw response data để debug
            if let rawResponseString = String(data: data, encoding: .utf8) {
                print("🎵 [TranscribeService] Raw API Response JSON:")
                print("   \(rawResponseString)")
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
            
            // Log parsed response để debug
            print("🎵 [TranscribeService] Parsed API Response:")
            print("   - Success: \(transcribeResponse.success)")
            print("   - Transcription (S3 URL): \(transcribeResponse.transcription)")
            print("   - Message (text): \(transcribeResponse.message ?? "nil")")
            print("   - Context ID: \(transcribeResponse.contextId ?? "nil")")
            print("   - Title: \(transcribeResponse.title ?? "nil")")
            print("   - Summary: \(transcribeResponse.summary ?? "nil")")
            print("   - Duration: \(transcribeResponse.durationSeconds ?? 0) seconds")
            
            guard transcribeResponse.success else {
                print("❌ [TranscribeService] API returned success=false")
                throw TranscribeError.transcriptionFailed
            }
            
            // Validate response có đủ data
            guard !transcribeResponse.transcription.isEmpty else {
                print("❌ [TranscribeService] Transcription URL is empty")
                throw TranscribeError.transcriptionFailed
            }
            
            guard let messageText = transcribeResponse.message, !messageText.isEmpty else {
                print("❌ [TranscribeService] Message text is empty")
                throw TranscribeError.transcriptionFailed
            }
            
            print("✅ [TranscribeService] Transcription successful!")
            print("   - Transcription URL (S3): \(transcribeResponse.transcription)")
            print("   - Message text: \(messageText)")
            print("   - Message text length: \(messageText.count) characters")
            
            return TranscribeResult(
                transcriptionURL: transcribeResponse.transcription,
                message: messageText,
                contextId: transcribeResponse.contextId,
                title: transcribeResponse.title,
                summary: transcribeResponse.summary,
                durationSeconds: transcribeResponse.durationSeconds
            )
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
            throw TranscribeError.timeout
        } catch {
            // Re-throw nếu đã là TranscribeError
            if error is TranscribeError {
                throw error
            }
            // Nếu là timeout error khác
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                throw TranscribeError.timeout
            }
            throw TranscribeError.requestFailed
        }
    }
    
    /// Transcribe video URL (YouTube, etc.) thành text
    /// - Parameters:
    ///   - videoURL: URL của video
    ///   - userId: ID của user
    /// - Returns: TranscribeResult chứa transcription URL (S3) và message text
    func transcribeVideoURL(videoURL: String, userId: Int) async throws -> TranscribeResult {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/video-url-mobile")!
        
        print("🎥 [TranscribeService] Starting video transcription...")
        print("   - Endpoint: \(url.absoluteString)")
        print("   - Video URL: \(videoURL)")
        print("   - User ID: \(userId)")
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "user_id": userId,
            "video_url": videoURL
        ]
        
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData
        
        // Log request details
        if let requestBodyString = String(data: requestBodyData, encoding: .utf8) {
            print("🎥 [TranscribeService] Request body JSON:")
            print("   \(requestBodyString)")
        }
        
        // ✅ Tăng timeout cho transcription (video có thể mất nhiều thời gian)
        request.timeoutInterval = 600 // 10 phút (600 giây)
        
        
        // Call API với error handling cho timeout
        let startTime = Date()
        do {
            print("🎥 [TranscribeService] Sending request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("🎥 [TranscribeService] Response received, size: \(data.count) bytes")
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscribeError.requestFailed
            }
            
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [TranscribeService] HTTP Error: \(httpResponse.statusCode)")
                    print("   - Raw response: \(errorString)")
                }
                throw TranscribeError.requestFailed
            }
            
            // Log raw response data để debug
            if let rawResponseString = String(data: data, encoding: .utf8) {
                print("🎥 [TranscribeService] Raw API Response JSON:")
                print("   \(rawResponseString)")
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
            
            // Log parsed response để debug
            print("🎥 [TranscribeService] Parsed API Response:")
            print("   - Success: \(transcribeResponse.success)")
            print("   - Transcription (S3 URL): \(transcribeResponse.transcription)")
            print("   - Message (text): \(transcribeResponse.message ?? "nil")")
            print("   - Context ID: \(transcribeResponse.contextId ?? "nil")")
            print("   - Title: \(transcribeResponse.title ?? "nil")")
            print("   - Summary: \(transcribeResponse.summary ?? "nil")")
            print("   - Duration: \(transcribeResponse.durationSeconds ?? 0) seconds")
            print("   - Elapsed time: \(String(format: "%.2f", elapsedTime)) seconds")
            
            guard transcribeResponse.success else {
                print("❌ [TranscribeService] API returned success=false")
                throw TranscribeError.transcriptionFailed
            }
            
            // Validate response có đủ data
            guard !transcribeResponse.transcription.isEmpty else {
                print("❌ [TranscribeService] Transcription URL is empty")
                throw TranscribeError.transcriptionFailed
            }
            
            guard let messageText = transcribeResponse.message, !messageText.isEmpty else {
                print("❌ [TranscribeService] Message text is empty")
                throw TranscribeError.transcriptionFailed
            }
            
            print("✅ [TranscribeService] Transcription successful!")
            print("   - Transcription URL (S3): \(transcribeResponse.transcription)")
            print("   - Message text: \(messageText)")
            print("   - Message text length: \(messageText.count) characters")
            
            return TranscribeResult(
                transcriptionURL: transcribeResponse.transcription,
                message: messageText,
                contextId: transcribeResponse.contextId,
                title: transcribeResponse.title,
                summary: transcribeResponse.summary,
                durationSeconds: transcribeResponse.durationSeconds
            )
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
            let elapsedTime = Date().timeIntervalSince(startTime)
            throw TranscribeError.timeout
        } catch {
            let elapsedTime = Date().timeIntervalSince(startTime)
            if let nsError = error as NSError? {
            }
            
            // Re-throw nếu đã là TranscribeError
            if error is TranscribeError {
                throw error
            }
            // Nếu là timeout error khác
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                throw TranscribeError.timeout
            }
            throw TranscribeError.requestFailed
        }
    }
}

// MARK: - Error Types

enum TranscribeError: LocalizedError {
    case requestFailed
    case transcriptionFailed
    case invalidFileFormat
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Cannot connect to transcribe server"
        case .transcriptionFailed:
            return "Cannot transcribe audio/video"
        case .invalidFileFormat:
            return "File format not supported"
        case .timeout:
            return "Transcription timeout. The video may be too long. Please try again."
        }
    }
}

