//
//  MediaFilePicker.swift
//  Chat-Ai
//
//  File picker hỗ trợ audio và video (MP3, WAV, MP4, MOV)
//

import SwiftUI
import UniformTypeIdentifiers

struct MediaFilePicker: UIViewControllerRepresentable {
    @Binding var selectedFile: FileAttachment?
    @Binding var selectedFileData: Data?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Hỗ trợ các loại file: MP3, WAV, MP4, MOV
        // UIDocumentPickerViewController sẽ tự động hiển thị tất cả các nguồn có sẵn
        // bao gồm: Files app, iCloud Drive, Photo Library, và các nguồn khác
        let contentTypes: [UTType] = [
            .audio,                    // Tất cả audio files (MP3, WAV, M4A, AAC, etc.)
            .mp3,                      // MP3
            .mpeg4Audio,               // M4A
            .movie,                    // Tất cả video files (MP4, MOV, AVI, etc.)
            .mpeg4Movie,               // MP4
            .quickTimeMovie            // MOV
        ]
        
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        // Cho phép truy cập tất cả các nguồn có sẵn
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: MediaFilePicker
        
        init(_ parent: MediaFilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                return
            }
            
            // Đọc file data trước (để validation có thể làm ở modal level)
                guard let data = try? Data(contentsOf: url) else {
                    return
                }
                
            // Kiểm tra file size (300MB = 300 * 1024 * 1024 bytes)
            // Note: Validation sẽ được làm ở UploadFileModal để hiển thị toast
            let maxSize: Int64 = 300 * 1024 * 1024
            let fileSize = Int64(data.count)
            
            do {
                // Vẫn log warning nhưng không block, để modal xử lý validation và hiển thị toast
                if fileSize > maxSize {
                }
                
                // Xác định loại file
                let fileName = url.lastPathComponent
                let fileExtension = url.pathExtension.lowercased()
                
                let fileType: FileAttachment.FileType
                if ["mp3", "wav", "m4a", "aac", "ogg", "oga", "opus"].contains(fileExtension) {
                    fileType = .audio
                } else if ["mp4", "mov", "avi", "mkv", "m4v"].contains(fileExtension) {
                    fileType = .video
                } else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.parent.selectedFile = FileAttachment(
                        url: "", // Sẽ được set sau khi upload
                        name: fileName,
                        type: fileType,
                        size: data.count
                    )
                    self.parent.selectedFileData = data
                    self.parent.dismiss()
                }
            } catch {
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled, dismiss picker
            DispatchQueue.main.async {
                self.parent.dismiss()
            }
        }
    }
}

