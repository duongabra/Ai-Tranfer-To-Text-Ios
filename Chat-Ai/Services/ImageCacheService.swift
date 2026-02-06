//
//  ImageCacheService.swift
//  Chat-Ai
//
//  Global image cache service để cache và preload ảnh
//

import Foundation
import UIKit

actor ImageCacheService {
    static let shared = ImageCacheService()
    
    private var cache: [String: UIImage] = [:]
    private var loadingTasks: [String: Task<UIImage?, Never>] = [:]
    
    private init() {}
    
    /// Load ảnh từ URL và cache lại
    func loadImage(url: URL) async -> UIImage? {
        let urlString = url.absoluteString
        
        // Kiểm tra cache trước
        if let cachedImage = cache[urlString] {
            return cachedImage
        }
        
        // Kiểm tra xem đang load chưa
        if let existingTask = loadingTasks[urlString] {
            return await existingTask.value
        }
        
        // Tạo task mới để load ảnh
        let task = Task<UIImage?, Never> {
            // Kiểm tra URLCache trước
            let cache = URLCache.shared
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            
            if let cachedResponse = cache.cachedResponse(for: request),
               let image = UIImage(data: cachedResponse.data) {
                // Đã có trong cache → lưu vào memory cache
                await self.cacheImage(url: urlString, image: image)
                return image
            }
            
            // Chưa có cache → load từ URL
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Lưu vào URLCache
                if let httpResponse = response as? HTTPURLResponse {
                    let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
                    cache.storeCachedResponse(cachedResponse, for: request)
                }
                
                // Convert sang UIImage
                guard let image = UIImage(data: data) else {
                    return nil
                }
                
                // Lưu vào memory cache
                await self.cacheImage(url: urlString, image: image)
                
                return image
            } catch {
                return nil
            }
        }
        
        loadingTasks[urlString] = task
        let result = await task.value
        loadingTasks.removeValue(forKey: urlString)
        
        return result
    }
    
    /// Lưu ảnh vào cache
    private func cacheImage(url: String, image: UIImage) async {
        cache[url] = image
    }
    
    /// Lấy ảnh từ cache (nếu có)
    func getCachedImage(url: URL) async -> UIImage? {
        return cache[url.absoluteString]
    }
    
    /// Preload ảnh (load trước khi cần)
    func preloadImage(url: URL) {
        Task {
            _ = await loadImage(url: url)
        }
    }
    
    /// Clear cache
    func clearCache() async {
        cache.removeAll()
    }
}
