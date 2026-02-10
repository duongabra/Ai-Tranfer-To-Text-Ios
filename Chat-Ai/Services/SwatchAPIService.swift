//
//  SwatchAPIService.swift
//  Chat-Ai
//
//  Gọi BE local: POST /api/mobile/swatches/recognize — nhận diện brand/product/shade từ 2 ảnh son.
//
//  Tích hợp Step 1 (processing 10s):
//  - Chạy timer 10s (progress 0→100). Gọi recognizeLipstick(imageURLs:) song song.
//  - Nếu API xong trước 10s → hiện state 4 (Lipstick identified) ngay với brand/product/shade từ response.
//  - Nếu hết 10s mà API chưa xong → giữ progress ở 99% cho đến khi API xong rồi mới hiện state 4.
//


import Foundation

/// Response từ POST /api/mobile/swatches/recognize
struct RecognizeLipstickResponse: Codable {
    let brand: String?
    let product: String?
    let shade: String?
    let hexCode: String?
    let isComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case brand
        case product
        case shade
        case hexCode = "hex_code"
        case isComplete = "is_complete"
    }
}

/// Request body: image_urls (ít nhất 2 URL)
struct RecognizeLipstickRequest: Encodable {
    let imageUrls: [String]

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
    }
}

// MARK: - Validate Face (Step 2)

/// Request body: POST /api/mobile/validate-face
struct ValidateFaceRequest: Encodable {
    let imageUrl: String

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
    }
}

/// Response: is_valid, score, checks, issues
struct ValidateFaceResponse: Codable {
    let isValid: Bool
    let score: Double?
    let checks: ValidateFaceChecks?
    let issues: [String]?

    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case score
        case checks
        case issues
    }
}

struct ValidateFaceChecks: Codable {
    let faceCentered: Bool?
    let faceNotCovered: Bool?
    let goodLighting: Bool?
    let neutralExpression: Bool?

    enum CodingKeys: String, CodingKey {
        case faceCentered = "face_centered"
        case faceNotCovered = "face_not_covered"
        case goodLighting = "good_lighting"
        case neutralExpression = "neutral_expression"
    }
}

// MARK: - Create Swatch (Step 3) + Get Swatch (polling)

/// Request: POST /api/mobile/swatches
struct CreateSwatchRequest: Encodable {
    let barefaceUrl: String
    let lipstickUrls: [String]
    let brand: String
    let product: String
    let shade: String

    enum CodingKeys: String, CodingKey {
        case barefaceUrl = "bareface_url"
        case lipstickUrls = "lipstick_urls"
        case brand
        case product
        case shade
    }
}

/// Response: POST create + GET by id (same shape)
struct SwatchDetailResponse: Codable {
    let id: String?
    let userId: String?
    let status: String?
    let errorMessage: String?
    let barefaceUrl: String?
    let lipstickUrls: [String]?
    let swatchUrl: String?
    let brand: String?
    let product: String?
    let shade: String?
    let hexCode: String?
    let score: Double?
    let aiDescription: String?
    let isFavorited: Bool?
    let feedback: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case errorMessage = "error_message"
        case barefaceUrl = "bareface_url"
        case lipstickUrls = "lipstick_urls"
        case swatchUrl = "swatch_url"
        case brand
        case product
        case shade
        case hexCode = "hex_code"
        case score
        case aiDescription = "ai_description"
        case isFavorited = "is_favorited"
        case feedback
        case createdAt = "created_at"
    }
}

enum SwatchAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpStatus(let code): return "Server returned \(code)"
        case .decoding(let e): return "Decode error: \(e.localizedDescription)"
        }
    }
}

actor SwatchAPIService {
    static let shared = SwatchAPIService()

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = AppConfig.swatchAPIBaseURL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    /// Recognize lipstick from at least 2 image URLs. Returns brand/product/shade (some may be null).
    func recognizeLipstick(imageURLs: [String]) async throws -> RecognizeLipstickResponse {
        guard imageURLs.count >= 2 else {
            throw SwatchAPIError.invalidResponse
        }
        let urlString = baseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/api/mobile/swatches/recognize"
        guard let url = URL(string: urlString) else {
            throw SwatchAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(RecognizeLipstickRequest(imageUrls: imageURLs))

        print("[SwatchAPI] POST \(urlString)")
        print("[SwatchAPI] image_urls: \(imageURLs)")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SwatchAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("[SwatchAPI] HTTP \(http.statusCode) body: \(body)")
            }
            throw SwatchAPIError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(RecognizeLipstickResponse.self, from: data)
        } catch {
            throw SwatchAPIError.decoding(error)
        }
    }

    /// Validate face image for swatch. Returns is_valid and checklist (face_centered, good_lighting, etc.).
    func validateFace(imageURL: String) async throws -> ValidateFaceResponse {
        let urlString = baseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/api/mobile/validate-face"
        guard let url = URL(string: urlString) else {
            throw SwatchAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(ValidateFaceRequest(imageUrl: imageURL))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SwatchAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("[SwatchAPI] validate-face HTTP \(http.statusCode) body: \(body)")
            }
            throw SwatchAPIError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(ValidateFaceResponse.self, from: data)
        } catch {
            throw SwatchAPIError.decoding(error)
        }
    }

    /// Create swatch and start generation. Returns id + status='processing'. Poll GET by id until completed.
    func createSwatch(barefaceUrl: String, lipstickUrls: [String], brand: String, product: String, shade: String) async throws -> SwatchDetailResponse {
        let urlString = baseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/api/mobile/swatches"
        guard let url = URL(string: urlString) else { throw SwatchAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(CreateSwatchRequest(
            barefaceUrl: barefaceUrl,
            lipstickUrls: lipstickUrls,
            brand: brand,
            product: product,
            shade: shade
        ))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SwatchAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) { print("[SwatchAPI] create swatch HTTP \(http.statusCode) body: \(body)") }
            throw SwatchAPIError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(SwatchDetailResponse.self, from: data)
    }

    /// Get swatch by id (for polling). Returns status, bareface_url, swatch_url, score, ai_description, etc.
    func getSwatch(swatchId: String) async throws -> SwatchDetailResponse {
        let urlString = baseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/api/mobile/swatches/\(swatchId)"
        guard let url = URL(string: urlString) else { throw SwatchAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SwatchAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) { print("[SwatchAPI] get swatch HTTP \(http.statusCode) body: \(body)") }
            throw SwatchAPIError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(SwatchDetailResponse.self, from: data)
    }
}
