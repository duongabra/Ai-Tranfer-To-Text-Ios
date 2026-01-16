//
//  EditProfileView+Extensions.swift
//  Chat-Ai
//
//  Extensions để hỗ trợ iOS 15 và iOS 16+
//

import SwiftUI
import PhotosUI

// MARK: - PhotosPicker Modifier for iOS 15 compatibility

struct PhotosPickerModifier: ViewModifier {
    @Binding var selectedImage: UIImage?
    @Binding var selectedItemStorage: Any?
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .modifier(iOS16PhotosPickerModifier(selectedImage: $selectedImage, selectedItemStorage: $selectedItemStorage))
        } else {
            content
        }
    }
}

@available(iOS 16.0, *)
struct iOS16PhotosPickerModifier: ViewModifier {
    @Binding var selectedImage: UIImage?
    @Binding var selectedItemStorage: Any?
    @State private var previousItemPointer: UnsafeRawPointer? = nil
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                updateImageIfNeeded()
            }
            .onChange(of: selectedItemStorage as? PhotosPickerItem) { newItem in
                if let item = newItem {
                    updateImage(from: item)
                }
            }
    }
    
    private func updateImageIfNeeded() {
        if let item = selectedItemStorage as? PhotosPickerItem {
            updateImage(from: item)
        }
    }
    
    private func updateImage(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                selectedImage = UIImage(data: data)
            }
        }
    }
}

// MARK: - View Extension


// MARK: - ImagePicker for iOS 15

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
