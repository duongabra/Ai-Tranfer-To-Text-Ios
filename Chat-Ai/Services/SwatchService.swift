//
//  SwatchService.swift
//  Chat-Ai
//
//  Service gọi API /api/mobile/swatches và /api/mobile/favorites
//

import Foundation

enum SwatchServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpStatus(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decoding(let e): return "Decode error: \(e.localizedDescription)"
        case .unauthorized: return "Session expired. Please login again."
        }
    }
}

actor SwatchService {
    static let shared = SwatchService()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: String = AppConfig.swatchAPIBaseURL) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.session = URLSession.shared

        // Custom decoder với ISO8601 date
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            // Try với fractional seconds
            if let date = formatter.date(from: dateStr) {
                return date
            }
            // Fallback không có fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateStr)")
        }
        self.decoder = decoder
    }

    // MARK: - Helper

    private func createAuthenticatedRequest(url: URL, method: String) async -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - List Swatches (My Swatches)

    /// Lấy danh sách swatches của user (paginated)
    func listSwatches(page: Int = 1, pageSize: Int = 20) async throws -> SwatchListResponse {
        guard let url = URL(string: "\(baseURL)/api/mobile/swatches?page=\(page)&page_size=\(pageSize)") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "GET")
        print("[SwatchService] GET \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(SwatchListResponse.self, from: data)
        } catch {
            print("[SwatchService] Decode error: \(error)")
            throw SwatchServiceError.decoding(error)
        }
    }

    // MARK: - List Favorites

    /// Lấy danh sách favorites của user (paginated)
    func listFavorites(page: Int = 1, pageSize: Int = 20) async throws -> SwatchListResponse {
        guard let url = URL(string: "\(baseURL)/api/mobile/favorites?page=\(page)&page_size=\(pageSize)") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "GET")
        print("[SwatchService] GET \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(SwatchListResponse.self, from: data)
        } catch {
            print("[SwatchService] Decode error: \(error)")
            throw SwatchServiceError.decoding(error)
        }
    }

    // MARK: - Get Swatch by ID

    /// Lấy chi tiết swatch
    func getSwatch(id: String) async throws -> Swatch {
        guard let url = URL(string: "\(baseURL)/api/mobile/swatches/\(id)") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(Swatch.self, from: data)
        } catch {
            throw SwatchServiceError.decoding(error)
        }
    }

    // MARK: - Toggle Favorite

    /// Toggle favorite status
    func toggleFavorite(swatchId: String) async throws -> FavoriteToggleResponse {
        guard let url = URL(string: "\(baseURL)/api/mobile/favorites/\(swatchId)") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "POST")
        print("[SwatchService] POST \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(FavoriteToggleResponse.self, from: data)
        } catch {
            throw SwatchServiceError.decoding(error)
        }
    }

    // MARK: - Delete Swatch

    /// Xóa swatch
    func deleteSwatch(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/mobile/swatches/\(id)") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "DELETE")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }
    }

    // MARK: - Submit Feedback

    /// Submit like/dislike feedback
    func submitFeedback(swatchId: String, isLiked: Bool) async throws -> FeedbackResponse {
        guard let url = URL(string: "\(baseURL)/api/mobile/feedbacks/\(swatchId)") else {
            throw SwatchServiceError.invalidURL
        }

        var request = await createAuthenticatedRequest(url: url, method: "POST")
        let body = ["is_liked": isLiked]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(FeedbackResponse.self, from: data)
        } catch {
            throw SwatchServiceError.decoding(error)
        }
    }

    // MARK: - Remove Feedback

    /// Remove feedback
    func removeFeedback(swatchId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/mobile/feedbacks/\(swatchId)") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "DELETE")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }
    }

    // MARK: - Regenerate Swatch

    /// Regenerate swatch
    func regenerateSwatch(id: String) async throws -> Swatch {
        guard let url = URL(string: "\(baseURL)/api/mobile/swatches/\(id)/regenerate") else {
            throw SwatchServiceError.invalidURL
        }

        let request = await createAuthenticatedRequest(url: url, method: "POST")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwatchServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw SwatchServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SwatchServiceError.httpStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(Swatch.self, from: data)
        } catch {
            throw SwatchServiceError.decoding(error)
        }
    }
}
