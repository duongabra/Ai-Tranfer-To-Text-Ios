//
//  AvatarView.swift
//  Chat-Ai
//
//  Reusable avatar view component với global cache (hiển thị ngay từ đầu)
//

import SwiftUI

struct AvatarView: View {
    let avatarURL: String?
    let size: CGFloat
    
    @State private var cachedImage: UIImage?
    
    init(avatarURL: String?, size: CGFloat = 64) {
        self.avatarURL = avatarURL
        self.size = size
    }
    
    var body: some View {
        Group {
            if let avatarURL = avatarURL,
               !avatarURL.isEmpty,
               let url = URL(string: avatarURL) {
                // Có avatarURL → load từ global cache
                ZStack {
                    // Ảnh mặc định luôn ở dưới
                    Image("DefaultAvatar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                    
                    // Ảnh từ cache
                    if let cachedImage = cachedImage {
                        // Đã có trong cache → hiển thị ngay
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    } else {
                        // Chưa có cache → load từ global cache service
                        Color.clear
                            .frame(width: size, height: size)
                            .task {
                                await loadImageFromCache(url: url)
                            }
                    }
                }
                .task(id: url) {
                    // Check cache ngay khi view render
                    await loadImageFromCache(url: url)
                }
            } else {
                // Không có avatarURL → hiển thị ảnh mặc định
                Image("DefaultAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .onChange(of: avatarURL) { newURL in
            // Khi avatarURL thay đổi → load ảnh mới
            if let newURL = newURL, !newURL.isEmpty, let url = URL(string: newURL) {
                Task {
                    await loadImageFromCache(url: url)
                }
            } else {
                cachedImage = nil
            }
        }
    }
    
    // Load ảnh từ global cache service
    private func loadImageFromCache(url: URL) async {
        // Kiểm tra cache trước (synchronous check trong memory)
        if let cached = await ImageCacheService.shared.getCachedImage(url: url) {
            await MainActor.run {
                cachedImage = cached
            }
            return
        }
        
        // Chưa có cache → load từ service (sẽ cache lại)
        if let image = await ImageCacheService.shared.loadImage(url: url) {
            await MainActor.run {
                cachedImage = image
            }
        }
    }
}
