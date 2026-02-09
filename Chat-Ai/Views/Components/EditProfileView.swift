//
//  EditProfileView.swift
//  Chat-Ai
//
//  Edit Profile popup trong Settings
//

import SwiftUI
import UIKit
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSaving = false
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var errorMessage: String? = nil
    
    // iOS 16+ PhotosPicker (dùng Any để tránh lỗi @available trên stored property)
    @State private var _selectedItemStorage: Any? = nil
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background blur overlay
            Color.white.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal content - bottom sheet
            VStack(spacing: 0) {
                // Content
                VStack(spacing: 16) {
                    // Avatar section
                    avatarSection
                    
                    // Input group
                    VStack(spacing: 16) {
                        // First Name input
                        inputField(
                            label: "First Name",
                            placeholder: "Enter your first name",
                            text: $firstName
                        )
                        
                        // Last Name input
                        inputField(
                            label: "Last name",
                            placeholder: "Enter your last name",
                            text: $lastName
                        )
                    }
                    .padding(.horizontal, 8)
                    
                    // Button group
                    HStack(spacing: 16) {
                        // Cancel button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
                                .foregroundColor(Color(hex: "#020202"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "#E4E4E4"), lineWidth: 1)
                                )
                        }
                        
                        // Save button
                        Button(action: {
                            handleSave()
                        }) {
                            Text("Save")
                                .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
                                .foregroundColor(Color(hex: "#FAFAFA"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.primaryOrange)
                                .cornerRadius(16)
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            // Load user data từ local trước
            loadUserData()
        }
        .modifier(PhotosPickerModifier(selectedImage: $selectedImage, selectedItemStorage: $_selectedItemStorage))
        .overlay(alignment: .top) {
            // Error toast message
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Text(error)
                        .font(Font.custom("Overused Grotesk", size: 14).weight(.regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: errorMessage)
                .zIndex(9999)
                .onAppear {
                    // Tự động ẩn sau 4 giây
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Avatar Section
    
    private var avatarSection: some View {
        VStack(spacing: 8) {
            ZStack {
                // Avatar image
                Group {
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        // Sử dụng AvatarView component
                        AvatarView(avatarURL: authViewModel.currentUser?.avatarURL, size: 80)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color.clear)
                .clipShape(Circle())
                
                // Camera icon overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if #available(iOS 16.0, *) {
                            PhotosPicker(selection: Binding(
                                get: { _selectedItemStorage as? PhotosPickerItem },
                                set: { _selectedItemStorage = $0 }
                            ), matching: .images) {
                                Image("camera_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            }
                            .offset(x: 0, y: 0)
                        } else {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Image("camera_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            }
                            .offset(x: 0, y: 0)
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .sheet(isPresented: $showingImagePicker) {
                    ProfileImagePicker(selectedImage: $selectedImage)
                }
            }
        }
    }
    
    // MARK: - Input Field
    
    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.custom("Overused Grotesk", size: 13).weight(.semibold))
                .foregroundColor(Color(hex: "#020202"))
            
            // Input
            TextField(placeholder, text: text)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "#020202"))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#E4E4E4"), lineWidth: 1)
                )
                .cornerRadius(16)
        }
        .frame(width: 360)
    }
    
    
    private func loadUserData() {
        // Load current user data into form
        Task {
            // Ưu tiên lấy từ user_metadata (first_name, last_name)
            let nameComponents = await AuthService.shared.getUserNameComponents()
            
            await MainActor.run {
                if let firstNameValue = nameComponents.firstName, !firstNameValue.isEmpty {
                    firstName = firstNameValue
                }
                if let lastNameValue = nameComponents.lastName, !lastNameValue.isEmpty {
                    lastName = lastNameValue
                }
                
                // Nếu không có trong user_metadata, fallback: parse từ displayName
                if firstName.isEmpty && lastName.isEmpty {
                    if let displayName = authViewModel.currentUser?.displayName {
                        let components = displayName.split(separator: " ")
                        if components.count >= 2 {
                            firstName = String(components[0])
                            lastName = String(components[1...].joined(separator: " "))
                        } else if components.count == 1 {
                            firstName = String(components[0])
                        }
                    }
                }
            }
        }
    }
    
    private func handleSave() {
        isSaving = true
        
        Task {
            do {
                var avatarURL: String? = nil
                
                // Bước 1: Upload avatar nếu có ảnh mới được chọn
                if let selectedImage = selectedImage,
                   let imageData = selectedImage.jpegData(compressionQuality: 0.8),
                   let userId = authViewModel.currentUser?.id {
                    avatarURL = try await SupabaseService.shared.uploadImageToStorage(
                        userId: userId,
                        imageData: imageData,
                        fileExtension: "jpg"
                    )
                }
                
                // Bước 2: Update user profile với firstName, lastName và avatarURL
                try await AuthService.shared.updateUserProfile(
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    avatarURL: avatarURL
                )
                
                // Bước 3: Cập nhật ngay currentUser trong AuthViewModel với dữ liệu mới
                await MainActor.run {
                    // Cập nhật avatarURL nếu có ảnh mới được upload
                    if var currentUser = authViewModel.currentUser {
                        if let avatarURL = avatarURL {
                            currentUser.avatarURL = avatarURL
                        }
                        authViewModel.currentUser = currentUser
                    }
                }
                
                // Bước 4: Refresh user data từ Supabase để lấy avatarURL từ DB
                // refreshCurrentUser() sẽ lấy avatarURL từ user_profiles table
                await authViewModel.refreshCurrentUser()
                
                // Bước 5: Gửi notification để các view khác refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: .userProfileUpdated, object: nil)
                    isSaving = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    
                    // Kiểm tra loại lỗi cụ thể
                    var errorMessageText = "Failed to save profile"
                    if let supabaseError = error as? SupabaseError {
                        switch supabaseError {
                        case .unauthorized:
                            errorMessageText = "Session expired. Please login again."
                        case .requestFailed:
                            errorMessageText = "Cannot connect to server. Please check your internet connection."
                        case .invalidURL:
                            errorMessageText = "Invalid request. Please try again."
                        case .decodingFailed:
                            errorMessageText = "Server response error. Please try again."
                        case .storageUploadFailed(let message):
                            errorMessageText = message
                        }
                    } else {
                        // Network error hoặc lỗi khác
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain {
                            switch nsError.code {
                            case NSURLErrorNotConnectedToInternet:
                                errorMessageText = "No internet connection. Please check your network."
                            case NSURLErrorTimedOut:
                                errorMessageText = "Request timed out. Please try again."
                            case NSURLErrorCannotConnectToHost:
                                errorMessageText = "Cannot connect to server. Please check your internet connection."
                            default:
                                errorMessageText = "Network error: \(error.localizedDescription)"
                            }
                        } else {
                            errorMessageText = "Failed to save profile: \(error.localizedDescription)"
                        }
                    }
                    
                    errorMessage = errorMessageText
                    
                    // Tự động ẩn error message sau 5 giây
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            errorMessage = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditProfileView(isPresented: .constant(true))
        .environmentObject(AuthViewModel())
}

