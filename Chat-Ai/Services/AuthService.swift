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
        
        // Lưu session
        await saveSession(user: user, accessToken: token)
        
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
        // Clear session
        currentSession = nil
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "accessToken") // ✅ Xóa access token
        
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
    func saveSession(user: User, accessToken: String) {
        currentSession = AuthSession(
            user: user,
            accessToken: accessToken
        )
        
        // Lưu vào UserDefaults
        UserDefaults.standard.set(user.id.uuidString, forKey: "userId")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(accessToken, forKey: "accessToken") // ✅ Lưu access token
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
            return "URL không hợp lệ"
        case .signInFailed:
            return "Đăng nhập thất bại"
        case .signOutFailed:
            return "Đăng xuất thất bại"
        case .notImplemented:
            return "Tính năng đang được phát triển"
        case .sessionExpired:
            return "Phiên đăng nhập đã hết hạn"
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

