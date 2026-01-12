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
    
    /// Kiểm tra xem user đã đăng nhập chưa
    func checkCurrentUser() {
        Task {
            currentUser = await AuthService.shared.getCurrentUser()
        }
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
            
            print("✅ Đăng nhập Apple thành công: \(user.email)")
            
        } catch let error as AuthError {
            // Lỗi từ AuthService
            errorMessage = error.localizedDescription
            print("❌ Lỗi đăng nhập Apple: \(error.localizedDescription)")
        } catch {
            // Lỗi khác
            errorMessage = "Apple login failed: \(error.localizedDescription)"
            print("❌ Lỗi đăng nhập Apple: \(error)")
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
            
            print("✅ Đăng nhập thành công: \(user.email)")
            
        } catch let error as AuthError {
            // Lỗi từ AuthService
            errorMessage = error.localizedDescription
            print("❌ Lỗi đăng nhập: \(error.localizedDescription)")
        } catch {
            // Lỗi khác
            errorMessage = "Login failed: \(error.localizedDescription)"
            print("❌ Lỗi đăng nhập: \(error)")
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
            
            print("✅ Đăng xuất thành công")
            
        } catch {
            errorMessage = "Logout failed: \(error.localizedDescription)"
            print("❌ Lỗi đăng xuất: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Handle Forced Logout
    
    /// Xử lý khi bị logout bắt buộc (do token hết hạn)
    private func handleForcedLogout() {
        currentUser = nil
        errorMessage = "Session expired. Please login again."
        print("⚠️ User bị logout do token hết hạn")
    }
}

