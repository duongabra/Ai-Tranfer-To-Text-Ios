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
}
