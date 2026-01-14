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
    
    // MARK: - Apple Sign In
    
    /// Sign in với Apple (Native Apple Sign In)
    /// - Returns: User đã đăng nhập
    @MainActor
    func signInWithApple() async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            var delegate: AppleSignInDelegate?
            var contextProvider: AppleSignInContextProvider?
            
            delegate = AppleSignInDelegate { result in
                // Đảm bảo continuation chỉ được resume 1 lần
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
                // Clear references sau khi hoàn thành
                delegate = nil
                contextProvider = nil
            }
            
            contextProvider = AppleSignInContextProvider()
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = contextProvider
            
            // Giữ strong reference đến delegate và context provider
            objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(authorizationController, "contextProvider", contextProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Giữ reference đến controller để tránh deallocate
            objc_setAssociatedObject(authorizationController, "controller", authorizationController, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            authorizationController.performRequests()
        }
    }
    
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
        
        // Nếu đăng nhập lần đầu và có ảnh từ Google/Apple, lưu vào DB
        if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
            Task {
                do {
                    // Kiểm tra xem đã có profile trong DB chưa
                    let existingProfile = try? await SupabaseService.shared.getUserProfile(userId: user.id)
                    if existingProfile == nil {
                        // Chưa có profile → đăng nhập lần đầu → lưu avatar vào DB
                        try await SupabaseService.shared.saveUserProfile(
                            userId: user.id,
                            firstName: nil,
                            lastName: nil,
                            avatarURL: avatarURL
                        )
                    }
                } catch {
                }
            }
        }
        
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
            // Ưu tiên avatar_url, nếu không có thì lấy picture (từ Google)
            avatarURL = userMetadata["avatar_url"] as? String ?? userMetadata["picture"] as? String
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
    }
    
    // MARK: - Update User Profile
    
    /// Cập nhật thông tin profile của user
    /// - Parameters:
    ///   - firstName: Tên
    ///   - lastName: Họ
    ///   - avatarURL: URL của avatar (optional)
    func updateUserProfile(firstName: String?, lastName: String?, avatarURL: String?) async throws {
        guard let userId = getCurrentUser()?.id else {
            throw AuthError.sessionExpired
        }
        
        // Lưu vào database (user_profiles table) thay vì user_metadata
        // Vì Supabase Auth merge với provider metadata và override custom fields
        try await SupabaseService.shared.saveUserProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            avatarURL: avatarURL
        )
        
        // Cập nhật avatar_url trong user_metadata nếu có (để hiển thị avatar)
        if let avatarURL = avatarURL {
            guard let accessToken = getAccessToken() else {
                throw AuthError.sessionExpired
            }
            
            guard let url = URL(string: "\(AppConfig.supabaseURL)/auth/v1/user") else {
                throw AuthError.invalidURL
            }
            
            // Fetch user_metadata hiện tại để merge
            var userMetadata: [String: Any] = [:]
            
            do {
                var metadataRequest = URLRequest(url: url)
                metadataRequest.httpMethod = "GET"
                metadataRequest.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                metadataRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let (metadataData, metadataResponse) = try await URLSession.shared.data(for: metadataRequest)
                
                if let httpResponse = metadataResponse as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let json = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                   let existingMetadata = json["user_metadata"] as? [String: Any] {
                    userMetadata = existingMetadata
                }
            } catch {
            }
            
            // Chỉ update avatar_url trong user_metadata
            userMetadata["avatar_url"] = avatarURL
            
            let requestBody: [String: Any] = [
                "user_metadata": userMetadata
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return // Exit function if update fails (non-critical, profile already saved to database)
            }
        }
        
    }
    
    // MARK: - Session Management
    
    /// Lấy user hiện tại từ session (chỉ từ UserDefaults, không fetch từ Supabase)
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
    
    /// Refresh user info từ Supabase (fetch metadata mới nhất)
    func refreshCurrentUser() async throws -> User {
        guard let accessToken = getAccessToken() else {
            throw AuthError.sessionExpired
        }
        
        var user = try await fetchUserInfo(accessToken: accessToken)
        
        // Lấy avatarURL từ database (user_profiles table) nếu có
        // Ưu tiên avatarURL từ DB vì đây là nơi lưu ảnh đã được user upload
        if let userId = getCurrentUser()?.id,
           let profile = try? await SupabaseService.shared.getUserProfile(userId: userId),
           let avatarURL = profile["avatar_url"] as? String, !avatarURL.isEmpty {
            user.avatarURL = avatarURL
        }
        
        // Cập nhật session với user mới
        if let session = currentSession {
            currentSession = AuthSession(user: user, accessToken: session.accessToken)
        }
        
        // Cập nhật UserDefaults với thông tin mới
        UserDefaults.standard.set(user.id.uuidString, forKey: "userId")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        
        return user
    }
    
    /// Lấy firstName và lastName từ database (user_profiles table)
    /// - Returns: Tuple (firstName, lastName) hoặc nil nếu không có
    func getUserNameComponents() async -> (firstName: String?, lastName: String?) {
        guard let userId = getCurrentUser()?.id else {
            return (nil, nil)
        }
        
        do {
            // Ưu tiên lấy từ database (user_profiles table)
            if let profile = try await SupabaseService.shared.getUserProfile(userId: userId) {
                let firstName = profile["first_name"] ?? nil
                let lastName = profile["last_name"] ?? nil
                
                if firstName != nil || lastName != nil {
                    return (firstName, lastName)
                }
            }
            
            // Fallback: parse từ displayName từ user_metadata
            guard let accessToken = getAccessToken() else {
                return (nil, nil)
            }
            
            let user = try await fetchUserInfo(accessToken: accessToken)
            
            if let displayName = user.displayName {
                return parseNameFromDisplayName(displayName)
            }
            
            return (nil, nil)
            
        } catch {
            // Fallback: parse từ currentUser.displayName
            if let currentUser = getCurrentUser(),
               let displayName = currentUser.displayName {
                return parseNameFromDisplayName(displayName)
            }
            return (nil, nil)
        }
    }
    
    /// Parse firstName và lastName từ displayName
    private func parseNameFromDisplayName(_ displayName: String?) -> (firstName: String?, lastName: String?) {
        guard let displayName = displayName, !displayName.isEmpty else {
            return (nil, nil)
        }
        
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return (String(components[0]), String(components[1...].joined(separator: " ")))
        } else if components.count == 1 {
            return (String(components[0]), nil)
        }
        
        return (nil, nil)
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
        }
        
        // ✅ Lưu thời gian hết hạn của access token (Supabase mặc định: 1 giờ)
        let expirationDate = Date().addingTimeInterval(3600) // 1 hour from now
        UserDefaults.standard.set(expirationDate, forKey: "accessTokenExpirationDate")
        
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
                    do {
                        _ = try await refreshAccessToken()
                    } catch {
                        // Nếu refresh thất bại, dừng timer và yêu cầu user đăng nhập lại
                        stopAutoRefreshTimer()
                    }
                }
            }
        }
        
    }
    
    /// Dừng background timer
    private func stopAutoRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
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
            return
        }
        
        do {
            _ = try await refreshAccessToken()
            // Bắt đầu timer sau khi refresh thành công
            startAutoRefreshTimer()
        } catch {
        }
    }
    
    // MARK: - Handle Unauthorized Error
    
    /// Xử lý lỗi 401 Unauthorized (token hết hạn)
    /// - Note: Tự động logout user và thông báo cần đăng nhập lại
    func handleUnauthorizedError() async {
        do {
            try await signOut()
            
            // ✅ Gửi notification để UI biết và update
            await MainActor.run {
                NotificationCenter.default.post(name: .userDidLogout, object: nil)
            }
            
        } catch {
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
    /// Notification khi user profile được cập nhật
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
}

// MARK: - Apple Sign In Context Provider

/// Context provider cho Apple Sign In
@MainActor
class AppleSignInContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("❌ Không tìm thấy window để hiển thị Apple Sign In")
        }
        return window
    }
}

// MARK: - Apple Sign In Delegate

/// Delegate để xử lý Apple Sign In callback
@MainActor
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<User, Error>) -> Void
    
    init(completion: @escaping (Result<User, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(AuthError.signInFailed))
            return
        }
        
        // Lấy identity token
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            completion(.failure(AuthError.signInFailed))
            return
        }
        
        // Lấy thông tin user
        let userID = appleIDCredential.user
        let email = appleIDCredential.email ?? "\(userID)@privaterelay.appleid.com"
        let fullName = appleIDCredential.fullName
        
        var displayName: String?
        if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
            displayName = "\(givenName) \(familyName)"
        } else if let givenName = fullName?.givenName {
            displayName = givenName
        }
        
        // Gửi identity token đến Supabase để authenticate
        Task {
            do {
                let user = try await self.authenticateWithSupabase(
                    identityToken: identityToken,
                    userID: userID,
                    email: email,
                    displayName: displayName
                )
                self.completion(.success(user))
            } catch {
                self.completion(.failure(error))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(AuthError.signInFailed))
    }
    
    /// Authenticate với Supabase sử dụng Apple identity token
    private func authenticateWithSupabase(identityToken: String, userID: String, email: String, displayName: String?) async throws -> User {
        // Gọi Supabase API để sign in với Apple
        guard let url = URL(string: "\(AppConfig.supabaseURL)/auth/v1/token?grant_type=id_token") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Body: provider và id_token
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.signInFailed
        }
        
        // Debug response
        if let responseString = String(data: data, encoding: .utf8) {
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.signInFailed
        }
        
        // Parse response để lấy access token và user info
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              let userJson = json["user"] as? [String: Any],
              let idString = userJson["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw AuthError.signInFailed
        }
        
        // Lấy avatar từ user_metadata nếu có (từ Apple)
        var avatarURL: String? = nil
        if let userJson = json["user"] as? [String: Any],
           let userMetadata = userJson["user_metadata"] as? [String: Any] {
            avatarURL = userMetadata["avatar_url"] as? String ?? userMetadata["picture"] as? String
        }
        
        // Tạo User object
        let user = User(
            id: id,
            email: email,
            createdAt: Date(),
            displayName: displayName,
            avatarURL: avatarURL
        )
        
        // Lưu session
        await AuthService.shared.saveSession(user: user, accessToken: accessToken, refreshToken: refreshToken)
        
        // Nếu đăng nhập lần đầu và có ảnh từ Apple, lưu vào DB
        if let avatarURL = avatarURL, !avatarURL.isEmpty {
            Task {
                do {
                    // Kiểm tra xem đã có profile trong DB chưa
                    let existingProfile = try? await SupabaseService.shared.getUserProfile(userId: id)
                    if existingProfile == nil {
                        // Chưa có profile → đăng nhập lần đầu → lưu avatar vào DB
                        try await SupabaseService.shared.saveUserProfile(
                            userId: id,
                            firstName: nil,
                            lastName: nil,
                            avatarURL: avatarURL
                        )
                    }
                } catch {
                }
            }
        }
        
        return user
    }
}

