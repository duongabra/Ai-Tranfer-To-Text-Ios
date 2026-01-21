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
    let transcriptionId: String?  // transcription_id từ API mới
    let conversationId: String?
    let contextId: String?
    let title: String?
    let summary: String?
    let transcription: String?  // S3 URL để download file (optional vì API có thể không trả về)
    let durationSeconds: Int?
    let message: String?       // Text transcription để hiển thị
    let s3Link: String?        // S3 link từ API mới
    
    enum CodingKeys: String, CodingKey {
        case success
        case transcriptionId = "transcription_id"
        case conversationId = "conversation_id"
        case contextId = "context_id"
        case title
        case summary
        case transcription
        case durationSeconds = "duration_seconds"
        case message
        case s3Link = "s3_link"
    }
}

// MARK: - Transcribe Result

/// Kết quả transcription chứa cả S3 URL và message text
struct TranscribeResult {
    let transcriptionId: String?  // transcription_id từ API
    let conversationId: String?   // conversation_id từ API (được tạo sau khi transcribe)
    let transcriptionURL: String  // S3 URL để download file
    let message: String           // Text transcription để hiển thị
    let contextId: String?
    let title: String?
    let summary: String?
    let durationSeconds: Int?
    let s3Link: String?          // S3 link từ API mới
}

// MARK: - Transcribe Service

actor TranscribeService {
    
    static let shared = TranscribeService()
    
    private init() {}
    
    /// Transcribe audio file thành text
    /// - Parameters:
    ///   - audioData: Data của audio file
    ///   - fileName: Tên file (cần có extension: .m4a, .mp3, .wav, .ogg, .oga, .opus)
    ///   - userId: ID của user (UUID string)
    /// - Returns: TranscribeResult chứa transcription_id, conversation_id, transcription URL (S3) và message text
    func transcribeAudio(audioData: Data, fileName: String, userId: String) async throws -> TranscribeResult {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/audio-mobile")!
        
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
            print("test log log10 : Starting transcribe audio request")
            print("test log log10 : File name: \(fileName), User ID: \(userId)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("test log log10 : Received response, data size: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("test log log10 : Response string (first 1000 chars): \(responseString.prefix(1000))")
                print("test log log10 : Full response string length: \(responseString.count)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("test log log10 : Invalid HTTP response")
                throw TranscribeError.requestFailed
            }
            
            print("test log log10 : HTTP status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("test log log10 : Error response: \(errorString)")
                    
                    // Check nếu lỗi liên quan đến user_id format
                    if errorString.contains("invalid literal for int()") || errorString.contains("user_id") {
                        print("test log log10 : ERROR - Backend expects integer user_id, but received UUID string")
                        print("test log log10 : Backend needs to be updated to accept UUID string instead of integer")
                        throw TranscribeError.invalidUserIdFormat
                    }
                }
                throw TranscribeError.requestFailed
            }
            
            // Parse response
            print("test log log10 : Attempting to decode JSON response")
            let decoder = JSONDecoder()
            // KHÔNG dùng keyDecodingStrategy vì đã có CodingKeys rõ ràng trong TranscribeResponse
            // decoder.keyDecodingStrategy = .convertFromSnakeCase  // XÓA vì conflict với CodingKeys
            
            // KHÔNG set date decoder vì TranscribeResponse không có Date field
            
            // Log raw JSON để debug
            if let jsonString = String(data: data, encoding: .utf8) {
                print("test log log10 : Raw JSON response: \(jsonString)")
            }
            
            // Thử decode như dictionary trước để xem structure
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("test log log10 : JSON is a dictionary with keys: \(jsonObject.keys.joined(separator: ", "))")
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("test log log10 : JSON is an array with \(jsonArray.count) elements")
                if let firstElement = jsonArray.first {
                    print("test log log10 : First element keys: \(firstElement.keys.joined(separator: ", "))")
                }
            }
            
            let transcribeResponse: TranscribeResponse
            do {
                // Thử decode như object trước
                do {
                    transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
                    print("test log log10 : Successfully decoded as object")
                } catch {
                    // Nếu không phải object, thử decode như array
                    print("test log log10 : Failed to decode as object, trying as array")
                    let arrayResponse = try decoder.decode([TranscribeResponse].self, from: data)
                    if let firstResponse = arrayResponse.first {
                        print("test log log10 : Successfully decoded as array, using first element")
                        transcribeResponse = firstResponse
                    } else {
                        print("test log log10 : Array is empty")
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Empty array response"))
                    }
                }
            } catch let decodingError as DecodingError {
                print("test log log10 : JSON decoding failed: \(decodingError)")
                switch decodingError {
                case .dataCorrupted(let context):
                    print("test log log10 : Data corrupted at path: \(context.codingPath)")
                    print("test log log10 : Description: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("test log log10 : Key not found: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("test log log10 : Type mismatch: \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("test log log10 : Value not found: \(type) at path: \(context.codingPath)")
                @unknown default:
                    print("test log log10 : Unknown decoding error")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("test log log10 : Failed JSON string: \(jsonString)")
                }
                throw decodingError
            }
            
            // Log giá trị sau khi decode
            print("test log log10 : Decoded response - success: \(transcribeResponse.success)")
            print("test log log10 : Decoded response - transcriptionId: \(transcribeResponse.transcriptionId ?? "nil")")
            print("test log log10 : Decoded response - conversationId: \(transcribeResponse.conversationId ?? "nil")")
            
            guard transcribeResponse.success else {
                print("test log log10 : Transcribe audio failed: success=false")
                throw TranscribeError.transcriptionFailed
            }
            
            // Validate response có đủ data
            guard let transcriptionId = transcribeResponse.transcriptionId, !transcriptionId.isEmpty else {
                print("test log log10 : Transcribe audio failed: No transcription_id in response")
                print("test log log10 : Response fields - success: \(transcribeResponse.success), transcriptionId: \(transcribeResponse.transcriptionId ?? "nil")")
                throw TranscribeError.transcriptionFailed
            }
            
            guard let conversationId = transcribeResponse.conversationId, !conversationId.isEmpty else {
                print("test log log10 : Transcribe audio failed: No conversation_id in response")
                throw TranscribeError.transcriptionFailed
            }
            
            print("test log log10 : Transcribe audio success, transcription_id: \(transcriptionId), conversation_id: \(conversationId)")
            return TranscribeResult(
                transcriptionId: transcriptionId,
                conversationId: conversationId,
                transcriptionURL: transcribeResponse.transcription ?? "",
                message: transcribeResponse.message ?? "",
                contextId: transcribeResponse.contextId,
                title: transcribeResponse.title,
                summary: transcribeResponse.summary,
                durationSeconds: transcribeResponse.durationSeconds,
                s3Link: transcribeResponse.s3Link
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
    ///   - userId: ID của user (UUID string)
    /// - Returns: TranscribeResult chứa transcription_id, conversation_id, transcription URL (S3) và message text
    func transcribeVideoURL(videoURL: String, userId: String) async throws -> TranscribeResult {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/video-url-mobile")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "user_id": "\(userId)",
            "video_url": videoURL
        ]
        
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData
        
        // ✅ Tăng timeout cho transcription (video có thể mất nhiều thời gian)
        request.timeoutInterval = 600 // 10 phút (600 giây)
        
        // Call API với error handling cho timeout
        let startTime = Date()
        do {
            print("test log log10 : Starting transcribe video URL request")
            print("test log log10 : Video URL: \(videoURL), User ID: \(userId)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("test log log10 : Received response after \(elapsedTime) seconds, data size: \(data.count) bytes")
            
            // Log raw JSON TRƯỚC KHI decode để debug
            if let responseString = String(data: data, encoding: .utf8) {
                print("test log log10 : Full raw JSON response: \(responseString)")
            }
            
            // Thử parse như dictionary/array TRƯỚC KHI decode với model
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("test log log10 : JSON is a dictionary with keys: \(jsonObject.keys.joined(separator: ", "))")
                for (key, value) in jsonObject {
                    print("test log log10 : Key '\(key)' has type: \(type(of: value))")
                }
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("test log log10 : JSON is an array with \(jsonArray.count) elements")
                if let firstElement = jsonArray.first {
                    print("test log log10 : First element keys: \(firstElement.keys.joined(separator: ", "))")
                    for (key, value) in firstElement {
                        print("test log log10 : Key '\(key)' has type: \(type(of: value)), value: \(value)")
                    }
                }
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                print("test log log10 : JSON is an array (not array of dictionaries) with \(jsonArray.count) elements")
                if let firstElement = jsonArray.first {
                    print("test log log10 : First element type: \(type(of: firstElement)), value: \(firstElement)")
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("test log log10 : Invalid HTTP response")
                throw TranscribeError.requestFailed
            }
            
            print("test log log10 : HTTP status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("test log log10 : Error response: \(errorString)")
                    
                    // Check nếu lỗi liên quan đến user_id format
                    if errorString.contains("invalid literal for int()") || errorString.contains("user_id") {
                        print("test log log10 : ERROR - Backend expects integer user_id, but received UUID string")
                        print("test log log10 : Backend needs to be updated to accept UUID string instead of integer")
                        throw TranscribeError.invalidUserIdFormat
                    }
                }
                throw TranscribeError.requestFailed
            }
            
            // Parse response
            print("test log log10 : Attempting to decode JSON response")
            let decoder = JSONDecoder()
            // KHÔNG dùng keyDecodingStrategy vì đã có CodingKeys rõ ràng trong TranscribeResponse
            // decoder.keyDecodingStrategy = .convertFromSnakeCase  // XÓA vì conflict với CodingKeys
            
            // KHÔNG set date decoder vì TranscribeResponse không có Date field
            // Nếu có lỗi date, có thể là do nested object hoặc array element có date
            
            let transcribeResponse: TranscribeResponse
            do {
                // Thử decode như object trước
                do {
                    transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
                    print("test log log10 : Successfully decoded as object")
                } catch {
                    // Nếu không phải object, thử decode như array
                    print("test log log10 : Failed to decode as object, trying as array")
                    let arrayResponse = try decoder.decode([TranscribeResponse].self, from: data)
                    if let firstResponse = arrayResponse.first {
                        print("test log log10 : Successfully decoded as array, using first element")
                        transcribeResponse = firstResponse
                    } else {
                        print("test log log10 : Array is empty")
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Empty array response"))
                    }
                }
            } catch let decodingError as DecodingError {
                print("test log log10 : JSON decoding failed: \(decodingError)")
                switch decodingError {
                case .dataCorrupted(let context):
                    print("test log log10 : Data corrupted at path: \(context.codingPath)")
                    print("test log log10 : Description: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("test log log10 : Key not found: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("test log log10 : Type mismatch: \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("test log log10 : Value not found: \(type) at path: \(context.codingPath)")
                @unknown default:
                    print("test log log10 : Unknown decoding error")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("test log log10 : Failed JSON string: \(jsonString)")
                }
                throw decodingError
            }
            
            // Log giá trị sau khi decode
            print("test log log10 : Decoded response - success: \(transcribeResponse.success)")
            print("test log log10 : Decoded response - transcriptionId: \(transcribeResponse.transcriptionId ?? "nil")")
            print("test log log10 : Decoded response - conversationId: \(transcribeResponse.conversationId ?? "nil")")
            
            guard transcribeResponse.success else {
                print("test log log10 : Transcribe video URL failed: success=false")
                throw TranscribeError.transcriptionFailed
            }
            
            // Validate response có đủ data
            guard let transcriptionId = transcribeResponse.transcriptionId, !transcriptionId.isEmpty else {
                print("test log log10 : Transcribe video URL failed: No transcription_id in response")
                print("test log log10 : Response fields - success: \(transcribeResponse.success), transcriptionId: \(transcribeResponse.transcriptionId ?? "nil")")
                throw TranscribeError.transcriptionFailed
            }
            
            guard let conversationId = transcribeResponse.conversationId, !conversationId.isEmpty else {
                print("test log log10 : Transcribe video URL failed: No conversation_id in response")
                throw TranscribeError.transcriptionFailed
            }
            
            print("test log log10 : Transcribe video URL success, transcription_id: \(transcriptionId), conversation_id: \(conversationId)")
            return TranscribeResult(
                transcriptionId: transcriptionId,
                conversationId: conversationId,
                transcriptionURL: transcribeResponse.transcription ?? "",
                message: transcribeResponse.message ?? "",
                contextId: transcribeResponse.contextId,
                title: transcribeResponse.title,
                summary: transcribeResponse.summary,
                durationSeconds: transcribeResponse.durationSeconds,
                s3Link: transcribeResponse.s3Link
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
    
    /// Transcribe audio URL (Supabase, S3, etc.) thành text
    /// - Parameters:
    ///   - audioURL: URL của audio file
    ///   - userId: ID của user (UUID string)
    /// - Returns: TranscribeResult chứa transcription_id, conversation_id, transcription URL (S3) và message text
    func transcribeAudioURL(audioURL: String, userId: String) async throws -> TranscribeResult {
        let url = URL(string: "\(AppConfig.transcribeAPIURL)/transcribe/audio-url-mobile")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Tạo request body
        let requestBody: [String: Any] = [
            "user_id": userId,
            "audio_url": audioURL
        ]
        
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData
        
        // ✅ Tăng timeout cho transcription (audio có thể mất nhiều thời gian)
        request.timeoutInterval = 600 // 10 phút (600 giây)
        
        // Call API với error handling cho timeout
        let startTime = Date()
        do {
            print("test log log10 : Starting transcribe audio URL request")
            print("test log log10 : Audio URL: \(audioURL), User ID: \(userId)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("test log log10 : Received response after \(elapsedTime) seconds, data size: \(data.count) bytes")
            
            // Log raw JSON TRƯỚC KHI decode để debug
            if let responseString = String(data: data, encoding: .utf8) {
                print("test log log10 : Full raw JSON response: \(responseString)")
            }
            
            // Thử parse như dictionary/array TRƯỚC KHI decode với model
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("test log log10 : JSON is a dictionary with keys: \(jsonObject.keys.joined(separator: ", "))")
                for (key, value) in jsonObject {
                    print("test log log10 : Key '\(key)' has type: \(type(of: value))")
                }
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("test log log10 : JSON is an array with \(jsonArray.count) elements")
                if let firstElement = jsonArray.first {
                    print("test log log10 : First element keys: \(firstElement.keys.joined(separator: ", "))")
                    for (key, value) in firstElement {
                        print("test log log10 : Key '\(key)' has type: \(type(of: value)), value: \(value)")
                    }
                }
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                print("test log log10 : JSON is an array (not array of dictionaries) with \(jsonArray.count) elements")
                if let firstElement = jsonArray.first {
                    print("test log log10 : First element type: \(type(of: firstElement)), value: \(firstElement)")
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("test log log10 : Invalid HTTP response")
                throw TranscribeError.requestFailed
            }
            
            print("test log log10 : HTTP status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("test log log10 : Error response: \(errorString)")
                    
                    // Check nếu lỗi liên quan đến user_id format
                    if errorString.contains("invalid literal for int()") || errorString.contains("user_id") {
                        print("test log log10 : ERROR - Backend expects integer user_id, but received UUID string")
                        print("test log log10 : Backend needs to be updated to accept UUID string instead of integer")
                        throw TranscribeError.invalidUserIdFormat
                    }
                }
                throw TranscribeError.requestFailed
            }
            
            // Parse response
            print("test log log10 : Attempting to decode JSON response")
            let decoder = JSONDecoder()
            // KHÔNG dùng keyDecodingStrategy vì đã có CodingKeys rõ ràng trong TranscribeResponse
            // decoder.keyDecodingStrategy = .convertFromSnakeCase  // XÓA vì conflict với CodingKeys
            
            // KHÔNG set date decoder vì TranscribeResponse không có Date field
            // Nếu có lỗi date, có thể là do nested object hoặc array element có date
            
            let transcribeResponse: TranscribeResponse
            do {
                // Thử decode như object trước
                do {
                    transcribeResponse = try decoder.decode(TranscribeResponse.self, from: data)
                    print("test log log10 : Successfully decoded as object")
                } catch {
                    // Nếu không phải object, thử decode như array
                    print("test log log10 : Failed to decode as object, trying as array")
                    let arrayResponse = try decoder.decode([TranscribeResponse].self, from: data)
                    if let firstResponse = arrayResponse.first {
                        print("test log log10 : Successfully decoded as array, using first element")
                        transcribeResponse = firstResponse
                    } else {
                        print("test log log10 : Array is empty")
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Empty array response"))
                    }
                }
            } catch let decodingError as DecodingError {
                print("test log log10 : JSON decoding failed: \(decodingError)")
                switch decodingError {
                case .dataCorrupted(let context):
                    print("test log log10 : Data corrupted at path: \(context.codingPath)")
                    print("test log log10 : Description: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("test log log10 : Key not found: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("test log log10 : Type mismatch: \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("test log log10 : Value not found: \(type) at path: \(context.codingPath)")
                @unknown default:
                    print("test log log10 : Unknown decoding error")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("test log log10 : Failed JSON string: \(jsonString)")
                }
                throw decodingError
            }
            
            // Log giá trị sau khi decode
            print("test log log10 : Decoded response - success: \(transcribeResponse.success)")
            print("test log log10 : Decoded response - transcriptionId: \(transcribeResponse.transcriptionId ?? "nil")")
            print("test log log10 : Decoded response - conversationId: \(transcribeResponse.conversationId ?? "nil")")
            
            guard transcribeResponse.success else {
                print("test log log10 : Transcribe audio URL failed: success=false")
                throw TranscribeError.transcriptionFailed
            }
            
            // Validate response có đủ data
            guard let transcriptionId = transcribeResponse.transcriptionId, !transcriptionId.isEmpty else {
                print("test log log10 : Transcribe audio URL failed: No transcription_id in response")
                print("test log log10 : Response fields - success: \(transcribeResponse.success), transcriptionId: \(transcribeResponse.transcriptionId ?? "nil")")
                throw TranscribeError.transcriptionFailed
            }
            
            guard let conversationId = transcribeResponse.conversationId, !conversationId.isEmpty else {
                print("test log log10 : Transcribe audio URL failed: No conversation_id in response")
                throw TranscribeError.transcriptionFailed
            }
            
            print("test log log10 : Transcribe audio URL success, transcription_id: \(transcriptionId), conversation_id: \(conversationId)")
            return TranscribeResult(
                transcriptionId: transcriptionId,
                conversationId: conversationId,
                transcriptionURL: transcribeResponse.transcription ?? "",
                message: transcribeResponse.message ?? "",
                contextId: transcribeResponse.contextId,
                title: transcribeResponse.title,
                summary: transcribeResponse.summary,
                durationSeconds: transcribeResponse.durationSeconds,
                s3Link: transcribeResponse.s3Link
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
    case invalidUserIdFormat
    
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
        case .invalidUserIdFormat:
            return "Backend configuration error: Please contact support. The server expects a different user ID format."
        }
    }
}

