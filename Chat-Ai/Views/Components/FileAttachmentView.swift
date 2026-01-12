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
            // ✅ Chỉ image mới mở fullscreen, audio/video play inline
            if attachment.isImage {
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
    
    // MARK: - Video Player View (Inline)
    
    private var videoThumbnailView: some View {
        InlineVideoPlayer(url: URL(string: attachment.url))
    }
    
    // MARK: - Audio Player View (Inline)
    
    private var audioPlayerView: some View {
        InlineAudioPlayer(url: URL(string: attachment.url), fileName: attachment.name)
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
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if attachment.isImage {
                    // ✅ Image viewer
                    AsyncImage(url: URL(string: attachment.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                Text("Failed to load image")
                            }
                            .foregroundColor(.white)
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if attachment.isVideo {
                    // ✅ Video player
                    if let url = URL(string: attachment.url) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .onAppear {
                                player = AVPlayer(url: url)
                            }
                            .onDisappear {
                                player?.pause()
                                player = nil
                            }
                    } else {
                        Text("Invalid video URL")
                            .foregroundColor(.white)
                    }
                } else if attachment.isAudio {
                    // ✅ Audio player với UI đẹp hơn
                    VStack(spacing: 24) {
                        // Audio icon
                        Image(systemName: "music.note.list")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        // File name
                        Text(attachment.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Audio player
                        if let url = URL(string: attachment.url) {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 60)
                                .cornerRadius(12)
                                .padding(.horizontal, 40)
                                .onAppear {
                                    player = AVPlayer(url: url)
                                }
                                .onDisappear {
                                    player?.pause()
                                    player = nil
                                }
                        } else {
                            Text("Invalid audio URL")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Close")
                        }
                        .foregroundColor(.white)
                    }
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

// MARK: - Inline Video Player

struct InlineVideoPlayer: View {
    let url: URL?
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let url = url {
                // Video layer
                VideoPlayer(player: player)
                    .frame(maxWidth: 250)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .onAppear {
                        player = AVPlayer(url: url)
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
                
                // Play/Pause overlay (chỉ hiện khi chưa play)
                if !isPlaying {
                    Color.black.opacity(0.3)
                        .frame(maxWidth: 250)
                        .frame(height: 200)
                        .cornerRadius(12)
                    
                    Button {
                        player?.play()
                        isPlaying = true
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(radius: 8)
                    }
                }
            } else {
                // Fallback
                ZStack {
                    Color.gray.opacity(0.2)
                        .frame(maxWidth: 250)
                        .frame(height: 200)
                        .cornerRadius(12)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("Invalid video URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Inline Audio Player

struct InlineAudioPlayer: View {
    let url: URL?
    let fileName: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Play/Pause button
                Button {
                    if isPlaying {
                        player?.pause()
                        isPlaying = false
                    } else {
                        if player == nil, let url = url {
                            player = AVPlayer(url: url)
                        }
                        player?.play()
                        isPlaying = true
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                .disabled(url == nil)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio File")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(12)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(maxWidth: 250)
        .onDisappear {
            player?.pause()
            player = nil
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

