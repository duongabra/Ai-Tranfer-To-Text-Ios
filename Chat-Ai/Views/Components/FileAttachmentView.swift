//
//  FileAttachmentView.swift
//  Chat-Ai
//
//  View để hiển thị file đính kèm trong message
//

import SwiftUI
import AVKit

// MARK: - FileAttachmentView

struct FileAttachmentView: View {
    
    let attachment: FileAttachment
    @State private var isShowingFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File content
            fileContentView
            
            // File info
            HStack(spacing: 4) {
                Image(systemName: attachment.type.icon)
                    .font(.caption2)
                
                Text(attachment.name)
                    .font(.caption2)
                    .lineLimit(1)
                
                Spacer()
                
                Text(attachment.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .onTapGesture {
            if attachment.isImage || attachment.isVideo {
                isShowingFullScreen = true
            }
        }
        .sheet(isPresented: $isShowingFullScreen) {
            FullScreenMediaView(attachment: attachment)
        }
    }
    
    // MARK: - File Content View
    
    @ViewBuilder
    private var fileContentView: some View {
        switch attachment.type {
        case .image:
            imageView
        case .video:
            videoThumbnailView
        case .audio:
            audioPlayerView
        case .other:
            genericFileView
        }
    }
    
    // MARK: - Image View
    
    private var imageView: some View {
        AsyncImage(url: URL(string: attachment.url)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(height: 200)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 250, maxHeight: 200)
                    .clipped()
                    .cornerRadius(12)
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(height: 200)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Video Thumbnail View
    
    private var videoThumbnailView: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(maxWidth: 250)
                .frame(height: 200)
                .cornerRadius(12)
            
            VStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                Text("Video")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Audio Player View
    
    private var audioPlayerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio File")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Tap to play")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(maxWidth: 250)
    }
    
    // MARK: - Generic File View
    
    private var genericFileView: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("File")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Tap to open")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(maxWidth: 250)
    }
}

// MARK: - FullScreenMediaView

struct FullScreenMediaView: View {
    
    let attachment: FileAttachment
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if attachment.isImage {
                    AsyncImage(url: URL(string: attachment.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Text("Failed to load image")
                                .foregroundColor(.white)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if attachment.isVideo {
                    if let url = URL(string: attachment.url) {
                        VideoPlayer(player: AVPlayer(url: url))
                    }
                } else if attachment.isAudio {
                    if let url = URL(string: attachment.url) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let url = URL(string: attachment.url) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FileAttachmentView(attachment: FileAttachment(
            url: "https://picsum.photos/400/300",
            name: "image.jpg",
            type: .image,
            size: 1024000
        ))
        
        FileAttachmentView(attachment: FileAttachment(
            url: "",
            name: "video.mp4",
            type: .video,
            size: 5242880
        ))
        
        FileAttachmentView(attachment: FileAttachment(
            url: "",
            name: "audio.mp3",
            type: .audio,
            size: 2048000
        ))
    }
    .padding()
}

