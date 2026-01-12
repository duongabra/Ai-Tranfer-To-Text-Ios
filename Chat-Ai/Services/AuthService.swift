//
//  AuthService.swift
//  Chat-Ai
//
//  Service để xử lý authentication với Supabase (Google Sign-In)
//

import Foundation
import UIKit
import AuthenticationServices

// Actor: đảm bảo thread-safe
actor AuthService {
    
    static let shared = AuthService()
    
    private init() {}
    
    // Lưu session hiện tại
    private var currentSession: AuthSession?
    
    // Presentation context provider (phải giữ strong reference)
    @MainActor
    private var presentationContextProvider: WebAuthenticationPresentationContextProvider?
    
    // ✅ Background timer để tự động refresh token
    private var refreshTimer: Task<Void, Never>?
    
    // MARK: - Google Sign In
    
    /// Sign in với Google (qua Supabase OAuth)
    /// - Returns: User đã đăng nhập
    func signInWithGoogle() async throws -> User {
        // Tạo OAuth URL từ Supabase
        // redirect_to: URL scheme để quay về app sau khi đăng nhập
        let redirectURL = "chatai://auth/callback"
        let authURL = "\(AppConfig.supabaseURL)/auth/v1/authorize?provider=google&redirect_to=\(redirectURL)"
        
        guard let url = URL(string: authURL) else {
            throw AuthError.invalidURL
        }
        
        // Sử dụng ASWebAuthenticationSession để mở browser
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                // Tạo và lưu presentation context provider
                await self.setPresentationContextProvider(WebAuthenticationPresentationContextProvider())
                
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "chatai"
                ) { callbackURL, error in
                    
                    // Xử lý error
                    if let error = error {
                        print("❌ OAuth error: \(error)")
                        continuation.resume(throwing: AuthError.signInFailed)
                        return
                    }
                    
                    // Xử lý callback URL
                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: AuthError.signInFailed)
                        return
                    }
                    
                    // Parse access token từ URL
                    Task {
                        do {
                            let user = try await self.handleOAuthCallback(url: callbackURL)
                            continuation.resume(returning: user)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                // Set presentation context provider
                if let provider = await self.getPresentationContextProvider() {
                    session.presentationContextProvider = provider
                }
                
                // Không lưu cookie → Luôn hiện màn hình chọn tài khoản Google
                session.prefersEphemeralWebBrowserSession = true
                
                // Start OAuth session
                session.start()
            }
        }
    }
    
    // MARK: - Handle OAuth Callback
    
    /// Xử lý callback sau khi OAuth thành công
    private func handleOAuthCallback(url: URL) async throws -> User {
        // Parse URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidURL
        }
        
        // Lấy access_token từ URL fragment
        // Format: chatai://auth/callback#access_token=xxx&refresh_token=yyy
        var accessToken: String?
        var refreshToken: String?
        
        if let fragment = components.fragment {
            let params = fragment.components(separatedBy: "&")
            for param in params {
                let keyValue = param.components(separatedBy: "=")
                if keyValue.count == 2 {
                    let key = keyValue[0]
                    let value = keyValue[1]
                    
                    if key == "access_token" {
                        accessToken = value
                    } else if key == "refresh_token" {
                        refreshToken = value
                    }
                }
            }
        }
        
        guard let token = accessToken else {
            throw AuthError.signInFailed
        }
        
        // Lấy user info từ Supabase
        let user = try await fetchUserInfo(accessToken: token)
        
        // Lưu session (bao gồm cả refresh token)
        await saveSession(user: user, accessToken: token, refreshToken: refreshToken)
        
        return user
    }
    
    // MARK: - Fetch User Info
    
    /// Lấy thông tin user từ Supabase
    private func fetchUserInfo(accessToken: String) async throws -> User {
        guard let url = URL(string: "\(AppConfig.supabaseURL)/auth/v1/user") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.signInFailed
        }
        
        // Parse JSON response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idString = json["id"] as? String,
              let id = UUID(uuidString: idString),
              let email = json["email"] as? String else {
            throw AuthError.signInFailed
        }
        
        // Optional: Parse thêm thông tin từ user_metadata
        var displayName: String?
        var avatarURL: String?
        
        if let userMetadata = json["user_metadata"] as? [String: Any] {
            displayName = userMetadata["full_name"] as? String
            avatarURL = userMetadata["avatar_url"] as? String
        }
        
        return User(
            id: id,
            email: email,
            createdAt: Date(),
            displayName: displayName,
            avatarURL: avatarURL
        )
    }
    
    // MARK: - Sign Out
    
    /// Đăng xuất
    func signOut() async throws {
        // ✅ Hủy background timer
        stopAutoRefreshTimer()
        
        // Clear session
        currentSession = nil
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
        UserDefaults.standard.removeObject(forKey: "accessTokenExpirationDate")
        
        // Với OAuth, chỉ cần clear local session là đủ
        // Không cần gọi Supabase logout endpoint vì token sẽ tự expire
        print("✅ Đăng xuất thành công")
    }
    
    // MARK: - Session Management
    
    /// Lấy user hiện tại từ session
    func getCurrentUser() -> User? {
        // Tạm thời lấy từ UserDefaults
        guard let userIdString = UserDefaults.standard.string(forKey: "userId"),
              let userId = UUID(uuidString: userIdString),
              let email = UserDefaults.standard.string(forKey: "userEmail") else {
            return nil
        }
        
        return User(
            id: userId,
            email: email,
            createdAt: Date()
        )
    }
    
    /// Lưu user session
    func saveSession(user: User, accessToken: String, refreshToken: String? = nil) {
        currentSession = AuthSession(
            user: user,
            accessToken: accessToken
        )
        
        // Lưu vào UserDefaults
        UserDefaults.standard.set(user.id.uuidString, forKey: "userId")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(accessToken, forKey: "accessToken") // Lưu access token
        
        // Lưu refresh token (để tự động renew access token)
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
            print("✅ Saved refresh token")
        }
        
        // ✅ Lưu thời gian hết hạn của access token (Supabase mặc định: 1 giờ)
        let expirationDate = Date().addingTimeInterval(3600) // 1 hour from now
        UserDefaults.standard.set(expirationDate, forKey: "accessTokenExpirationDate")
        print("✅ Access token will expire at: \(expirationDate)")
        
        // ✅ Bắt đầu background timer để tự động refresh token
        startAutoRefreshTimer()
    }
    
    /// Lấy access token hiện tại
    func getAccessToken() -> String? {
        // Ưu tiên lấy từ currentSession
        if let session = currentSession {
            return session.accessToken
        }
        
        // Fallback: Lấy từ UserDefaults
        return UserDefaults.standard.string(forKey: "accessToken")
    }
    
    // MARK: - Refresh Token
    
    /// Refresh access token khi hết hạn
    /// - Returns: Access token mới
    func refreshAccessToken() async throws -> String {
        // Lấy refresh token từ UserDefaults
        guard let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
            print("❌ No refresh token found")
            throw AuthError.sessionExpired
        }
        
        // Gọi Supabase API để refresh token
        guard let url = URL(string: "\(AppConfig.supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Body: refresh_token
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ Refresh token failed")
            throw AuthError.sessionExpired
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String,
              let newRefreshToken = json["refresh_token"] as? String else {
            throw AuthError.signInFailed
        }
        
        // Lưu token mới
        UserDefaults.standard.set(newAccessToken, forKey: "accessToken")
        UserDefaults.standard.set(newRefreshToken, forKey: "refreshToken")
        
        // ✅ Cập nhật expiration date mới (1 giờ từ bây giờ)
        let newExpirationDate = Date().addingTimeInterval(3600)
        UserDefaults.standard.set(newExpirationDate, forKey: "accessTokenExpirationDate")
        
        print("✅ Access token refreshed successfully (expires at: \(newExpirationDate))")
        return newAccessToken
    }
    
    // MARK: - Auto Refresh Timer
    
    /// Bắt đầu background timer để tự động refresh token trước khi hết hạn
    /// - Note: Timer sẽ kiểm tra và refresh token trước 5 phút khi sắp hết hạn
    private func startAutoRefreshTimer() {
        // Hủy timer cũ nếu có
        stopAutoRefreshTimer()
        
        // Tạo timer mới
        refreshTimer = Task {
            while !Task.isCancelled {
                // Đợi 5 phút trước khi check
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
                
                // Kiểm tra xem token có sắp hết hạn không
                if shouldRefreshToken() {
                    print("🔄 Token sắp hết hạn, đang refresh...")
                    do {
                        _ = try await refreshAccessToken()
                        print("✅ Token đã được refresh tự động")
                    } catch {
                        print("❌ Lỗi khi refresh token tự động: \(error)")
                        // Nếu refresh thất bại, dừng timer và yêu cầu user đăng nhập lại
                        stopAutoRefreshTimer()
                    }
                }
            }
        }
        
        print("✅ Đã bắt đầu auto-refresh timer")
    }
    
    /// Dừng background timer
    private func stopAutoRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
        print("✅ Đã dừng auto-refresh timer")
    }
    
    /// Kiểm tra xem có nên refresh token không
    /// - Returns: true nếu token sắp hết hạn (còn dưới 10 phút)
    private func shouldRefreshToken() -> Bool {
        guard let expirationDate = UserDefaults.standard.object(forKey: "accessTokenExpirationDate") as? Date else {
            return false // Không có expiration date, không cần refresh
        }
        
        // Refresh nếu còn dưới 10 phút
        let timeUntilExpiration = expirationDate.timeIntervalSinceNow
        return timeUntilExpiration < 600 // 10 minutes
    }
    
    /// Kiểm tra và refresh token nếu cần (gọi khi app khởi động)
    func checkAndRefreshTokenIfNeeded() async {
        guard shouldRefreshToken() else {
            print("✅ Token còn hạn, không cần refresh")
            return
        }
        
        print("🔄 Token sắp hết hạn, đang refresh...")
        do {
            _ = try await refreshAccessToken()
            print("✅ Token đã được refresh")
            // Bắt đầu timer sau khi refresh thành công
            startAutoRefreshTimer()
        } catch {
            print("❌ Lỗi khi refresh token: \(error)")
        }
    }
    
    // MARK: - Handle Unauthorized Error
    
    /// Xử lý lỗi 401 Unauthorized (token hết hạn)
    /// - Note: Tự động logout user và thông báo cần đăng nhập lại
    func handleUnauthorizedError() async {
        print("⚠️ Token hết hạn, đang logout user...")
        do {
            try await signOut()
            
            // ✅ Gửi notification để UI biết và update
            await MainActor.run {
                NotificationCenter.default.post(name: .userDidLogout, object: nil)
            }
            
            print("✅ Đã logout user do token hết hạn")
        } catch {
            print("❌ Lỗi khi logout: \(error)")
        }
    }
    
    // MARK: - Presentation Context Provider Helpers
    
    @MainActor
    private func setPresentationContextProvider(_ provider: WebAuthenticationPresentationContextProvider) {
        self.presentationContextProvider = provider
    }
    
    @MainActor
    private func getPresentationContextProvider() -> WebAuthenticationPresentationContextProvider? {
        return self.presentationContextProvider
    }
}

// MARK: - Supporting Types

/// Auth Session
struct AuthSession {
    let user: User
    let accessToken: String
}

/// Auth Errors
enum AuthError: LocalizedError {
    case invalidURL
    case signInFailed
    case signOutFailed
    case notImplemented
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .signInFailed:
            return "Login failed"
        case .signOutFailed:
            return "Logout failed"
        case .notImplemented:
            return "Feature under development"
        case .sessionExpired:
            return "Session expired"
        }
    }
}

// MARK: - Presentation Context Provider

/// Cung cấp window context cho ASWebAuthenticationSession
@MainActor
class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Lấy window đầu tiên từ UIApplication
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("❌ Không tìm thấy window để hiển thị OAuth")
        }
        return window
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Notification khi user bị logout (do token hết hạn)
    static let userDidLogout = Notification.Name("userDidLogout")
}

