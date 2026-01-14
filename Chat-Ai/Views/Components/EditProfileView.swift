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
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    
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
        .onChange(of: selectedItem) { newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedImage = UIImage(data: data)
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
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image("camera_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        }
                        .offset(x: 0, y: 0)
                    }
                }
                .frame(width: 80, height: 80)
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
                   let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
                    avatarURL = try await StorageService.shared.uploadFile(
                        data: imageData,
                        fileName: "avatar_\(UUID().uuidString).jpg",
                        fileType: .image
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
                    // TODO: Show error message to user
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

