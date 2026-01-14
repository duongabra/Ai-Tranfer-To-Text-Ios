//
//  AuthViewModel.swift
//  Chat-Ai
//
//  ViewModel quản lý authentication state
//

import Foundation

@MainActor
class AuthViewModel: ObservableObject {
    
    // @Published: Khi giá trị thay đổi → UI tự động update
    @Published var currentUser: User?           // User hiện tại (nil = chưa đăng nhập)
    @Published var isLoading = false            // Đang xử lý đăng nhập?
    @Published var errorMessage: String?        // Thông báo lỗi
    
    init() {
        // Check xem user đã đăng nhập chưa khi app launch
        checkCurrentUser()
        
        // ✅ Lắng nghe notification khi user bị logout (do token hết hạn)
        NotificationCenter.default.addObserver(
            forName: .userDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleForcedLogout()
        }
    }
    
    // MARK: - Check Current User
    
    /// Kiểm tra xem user đã đăng nhập chưa và load đầy đủ thông tin từ DB
    func checkCurrentUser() {
        Task {
            // Lấy user cơ bản từ UserDefaults trước
            guard let user = await AuthService.shared.getCurrentUser() else {
                return
            }
            
            // Load đầy đủ thông tin từ DB TRƯỚC khi set currentUser
            // Để tránh UI hiển thị avatar mặc định (chữ A) trước khi load xong
            var updatedUser = user
            await loadUserInfoFromDBIntoUser(userId: user.id, user: &updatedUser)
            
            // Chỉ set currentUser SAU KHI đã load đầy đủ thông tin từ DB
            currentUser = updatedUser
            
            // Preload avatar image ngay khi có avatarURL
            if let avatarURL = updatedUser.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                Task {
                    await ImageCacheService.shared.preloadImage(url: url)
                }
            }
            
        }
    }
    
    /// Load đầy đủ thông tin user từ DB và cập nhật vào user object (không set currentUser)
    /// Dùng khi muốn load TRƯỚC khi set currentUser để tránh UI flash
    private func loadUserInfoFromDBIntoUser(userId: UUID, user: inout User) async {
        do {
            // Lấy profile từ DB
            guard let profile = try await SupabaseService.shared.getUserProfile(userId: userId) else {
                return
            }
            
            
            // Load avatarURL từ DB
            let avatarURL = profile["avatar_url"] as? String
            
            // Cập nhật user object với avatarURL từ DB
            let oldAvatarURL = user.avatarURL
            user.avatarURL = avatarURL
            
            // Preload avatar image ngay khi có avatarURL
            if let avatarURL = avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                Task {
                    await ImageCacheService.shared.preloadImage(url: url)
                }
            }
            
        } catch {
        }
    }
    
    /// Load đầy đủ thông tin user từ DB (avatarURL, firstName, lastName)
    /// Method chung được gọi ở nhiều nơi để đảm bảo có data mới nhất
    /// Method này sẽ cập nhật currentUser trực tiếp
    func loadUserInfoFromDB(userId: UUID) async {
        do {
            // Lấy profile từ DB
            guard let profile = try await SupabaseService.shared.getUserProfile(userId: userId) else {
                return
            }
            
            
            // Load avatarURL từ DB
            let avatarURL = profile["avatar_url"] as? String
            
            // Cập nhật currentUser với avatarURL từ DB
            if var user = currentUser, user.id == userId {
                let oldAvatarURL = user.avatarURL
                user.avatarURL = avatarURL
                currentUser = user
            } else {
                // Nếu currentUser chưa có, lấy từ AuthService và set
                if let basicUser = await AuthService.shared.getCurrentUser(), basicUser.id == userId {
                    var updatedUser = basicUser
                    updatedUser.avatarURL = avatarURL
                    currentUser = updatedUser
                } else {
                }
            }
        } catch {
        }
    }
    
    /// Refresh user info từ Supabase và load từ DB
    func refreshCurrentUser() async {
        do {
            let refreshedUser = try await AuthService.shared.refreshCurrentUser()
            
            // Set currentUser trước
            currentUser = refreshedUser
            
            // Load thông tin từ DB để đảm bảo có avatarURL mới nhất
            await loadUserInfoFromDB(userId: refreshedUser.id)
            
        } catch {
            // Fallback: chỉ load từ DB nếu có currentUser
            if let userId = currentUser?.id {
                await loadUserInfoFromDB(userId: userId)
            }
        }
    }
    
    /// Lấy full name từ firstName + lastName (từ database) hoặc displayName (fallback)
    func getUserDisplayName() async -> String {
        let nameComponents = await AuthService.shared.getUserNameComponents()
        
        // Nếu có firstName và lastName từ database
        if let firstName = nameComponents.firstName, !firstName.isEmpty,
           let lastName = nameComponents.lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if let firstName = nameComponents.firstName, !firstName.isEmpty {
            return firstName
        } else if let lastName = nameComponents.lastName, !lastName.isEmpty {
            return lastName
        }
        
        // Fallback: dùng displayName từ user_metadata
        return currentUser?.displayName ?? currentUser?.email ?? "User"
    }
    
    // MARK: - Sign In with Apple
    
    /// Đăng nhập với Apple
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Gọi AuthService để đăng nhập
            let user = try await AuthService.shared.signInWithApple()
            
            // Update UI
            currentUser = user
            
            // Load đầy đủ thông tin từ DB sau khi đăng nhập
            await loadUserInfoFromDB(userId: user.id)
            
            
        } catch let error as AuthError {
            // Lỗi từ AuthService
            errorMessage = error.localizedDescription
        } catch {
            // Lỗi khác
            errorMessage = "Apple login failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In with Google
    
    /// Đăng nhập với Google
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Gọi AuthService để đăng nhập
            let user = try await AuthService.shared.signInWithGoogle()
            
            // Update UI
            currentUser = user
            
            // Load đầy đủ thông tin từ DB sau khi đăng nhập
            await loadUserInfoFromDB(userId: user.id)
            
            
        } catch let error as AuthError {
            // Lỗi từ AuthService
            errorMessage = error.localizedDescription
        } catch {
            // Lỗi khác
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    /// Đăng xuất
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Gọi AuthService để đăng xuất
            try await AuthService.shared.signOut()
            
            // Clear current user
            currentUser = nil
            
            
        } catch {
            errorMessage = "Logout failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Handle Forced Logout
    
    /// Xử lý khi bị logout bắt buộc (do token hết hạn)
    private func handleForcedLogout() {
        currentUser = nil
        errorMessage = "Session expired. Please login again."
    }
}

