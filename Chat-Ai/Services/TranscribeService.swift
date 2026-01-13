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
        
        // ✅ Tăng timeout cho transcription (video/audio có thể mất nhiều thời gian)
        request.timeoutInterval = 600 // 10 phút (600 giây)
        
        // Call API với error handling cho timeout
        do {
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
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
            print("❌ Transcription timeout: \(error.localizedDescription)")
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
    /// - Returns: Text transcription
    func transcribeVideoURL(videoURL: String, userId: Int) async throws -> String {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/video-url")!
        
        print("🔗 Transcribe API URL: \(url.absoluteString)")
        print("📹 Video URL: \(videoURL)")
        print("👤 User ID: \(userId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "user_id": userId,
            "video_url": videoURL
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // ✅ Tăng timeout cho transcription (video có thể mất nhiều thời gian)
        request.timeoutInterval = 600 // 10 phút (600 giây)
        
        print("⏱️ Request timeout: \(request.timeoutInterval) seconds")
        print("📤 Sending transcription request...")
        
        // Call API với error handling cho timeout
        let startTime = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("⏱️ Request completed in \(String(format: "%.2f", elapsedTime)) seconds")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw TranscribeError.requestFailed
            }
            
            print("📥 Response Status: \(httpResponse.statusCode)")
            print("📥 Response Headers: \(httpResponse.allHeaderFields)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Transcribe Video Error - Status: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Error Response: \(errorString)")
                }
                throw TranscribeError.requestFailed
            }
            
            print("✅ Received response data: \(data.count) bytes")
            
            // Parse response
            let decoder = JSONDecoder()
            let transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
            
            guard transcribeResponse.success else {
                throw TranscribeError.transcriptionFailed
            }
            
            print("✅ Video transcribed successfully")
            return transcribeResponse.transcription
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("❌ Transcription timeout after \(String(format: "%.2f", elapsedTime)) seconds")
            print("❌ Error: \(error.localizedDescription)")
            print("❌ Error code: \(error.code)")
            throw TranscribeError.timeout
        } catch {
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("❌ Transcription error after \(String(format: "%.2f", elapsedTime)) seconds")
            print("❌ Error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error userInfo: \(nsError.userInfo)")
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

