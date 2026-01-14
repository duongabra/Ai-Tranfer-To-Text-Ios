//
//  UnifiedMediaPicker.swift
//  Chat-Ai
//
//  Unified picker để chọn media từ tất cả các nguồn (Photo Library + Files)
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UnifiedMediaPicker: View {
    @Binding var selectedFile: FileAttachment?
    @Binding var selectedFileData: Data?
    @Environment(\.dismiss) var dismiss
    
    @State private var showingPhotoLibrary = false
    @State private var showingFiles = false
    @State private var showingSourcePicker = true
    
    var body: some View {
        Color.white
            .ignoresSafeArea()
            .confirmationDialog("Select Source", isPresented: $showingSourcePicker, titleVisibility: .hidden) {
                Button("Photo Library") {
                    showingPhotoLibrary = true
                }
                Button("Files") {
                    showingFiles = true
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }
            .onChange(of: showingSourcePicker) { newValue in
                // Nếu action sheet đóng mà không có sheet con nào đang mở thì dismiss
                if !newValue && !showingPhotoLibrary && !showingFiles {
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPhotoLibrary, onDismiss: {
                // Khi PhotoLibraryPicker đóng, dismiss UnifiedMediaPicker
                dismiss()
            }) {
                PhotoLibraryPicker(
                    selectedFile: $selectedFile,
                    selectedFileData: $selectedFileData
                )
            }
            .sheet(isPresented: $showingFiles, onDismiss: {
                // Khi MediaFilePicker đóng, dismiss UnifiedMediaPicker
                dismiss()
            }) {
                MediaFilePicker(
                    selectedFile: $selectedFile,
                    selectedFileData: $selectedFileData
                )
            }
    }
}

// MARK: - Photo Library Picker (cho video)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedFile: FileAttachment?
    @Binding var selectedFileData: Data?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos // Chỉ video từ Photo Library
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        
        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            // Nếu user không chọn file (cancel), dismiss luôn
            guard let result = results.first else {
                DispatchQueue.main.async {
                    self.parent.dismiss()
                }
                return
            }
            
            let itemProvider = result.itemProvider
            
            // Kiểm tra file size (300MB)
            let maxSize: Int64 = 300 * 1024 * 1024
            
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    guard let self = self, let url = url else {
                        return
                    }
                    
                    // Đọc file data trước (để validation có thể làm ở modal level)
                    guard let data = try? Data(contentsOf: url) else {
                        return
                    }
                    
                    // Kiểm tra file size
                    // Note: Validation sẽ được làm ở UploadFileModal để hiển thị toast
                    let fileSize = Int64(data.count)
                    if fileSize > maxSize {
                    }
                    
                    DispatchQueue.main.async {
                        let fileName = url.lastPathComponent.isEmpty ? "video_\(Date().timeIntervalSince1970).mp4" : url.lastPathComponent
                        self.parent.selectedFile = FileAttachment(
                            url: "",
                            name: fileName,
                            type: .video,
                            size: data.count
                        )
                        self.parent.selectedFileData = data
                        self.parent.dismiss()
                    }
                }
            }
        }
    }
}

