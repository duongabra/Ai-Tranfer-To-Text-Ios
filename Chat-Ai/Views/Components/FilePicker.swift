//
//  FilePicker.swift
//  Chat-Ai
//
//  Helper để pick ảnh, video, audio từ thư viện
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - FilePicker

/// SwiftUI wrapper cho PHPickerViewController (pick ảnh/video)
struct FilePicker: UIViewControllerRepresentable {
    
    @Binding var selectedFile: FileAttachment?
    @Binding var selectedData: Data?
    let fileTypes: [FileAttachment.FileType]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        
        // Cấu hình loại file được chọn
        var filter: [PHPickerFilter] = []
        if fileTypes.contains(.image) {
            filter.append(.images)
        }
        if fileTypes.contains(.video) {
            filter.append(.videos)
        }
        
        configuration.filter = .any(of: filter)
        configuration.selectionLimit = 1 // Chỉ chọn 1 file
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: FilePicker
        
        init(_ parent: FilePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            // Lấy thông tin file
            let itemProvider = result.itemProvider
            
            // Kiểm tra loại file
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                // Xử lý ảnh
                itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    guard let self = self,
                          let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.8) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                        self.parent.selectedFile = FileAttachment(
                            url: "", // Sẽ được set sau khi upload
                            name: fileName,
                            type: .image,
                            size: data.count
                        )
                        self.parent.selectedData = data
                    }
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                // Xử lý video
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    guard let self = self,
                          let url = url,
                          let data = try? Data(contentsOf: url) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        let fileName = "video_\(Date().timeIntervalSince1970).mp4"
                        self.parent.selectedFile = FileAttachment(
                            url: "", // Sẽ được set sau khi upload
                            name: fileName,
                            type: .video,
                            size: data.count
                        )
                        self.parent.selectedData = data
                    }
                }
            }
        }
    }
}

// MARK: - AudioPicker

/// Document picker cho audio files
struct AudioPicker: UIViewControllerRepresentable {
    
    @Binding var selectedFile: FileAttachment?
    @Binding var selectedData: Data?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.audio, .mp3],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AudioPicker
        
        init(_ parent: AudioPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  let data = try? Data(contentsOf: url) else {
                return
            }
            
            DispatchQueue.main.async {
                let fileName = url.lastPathComponent
                self.parent.selectedFile = FileAttachment(
                    url: "", // Sẽ được set sau khi upload
                    name: fileName,
                    type: .audio,
                    size: data.count
                )
                self.parent.selectedData = data
            }
        }
    }
}

