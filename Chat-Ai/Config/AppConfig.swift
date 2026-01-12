//
//  AppConfig.swift
//  Chat-Ai
//
//  File cấu hình - Đọc từ Info.plist (inject từ Config.xcconfig)
//  ✅ Config.xcconfig tương tự .env trong web
//  ✅ Không commit Config.xcconfig lên Git
//

import Foundation

struct AppConfig {
    
    // MARK: - Helper
    
    /// Đọc value từ Info.plist (được inject từ Config.xcconfig)
    private static func infoPlistValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("$(") else { // Kiểm tra không phải placeholder
            fatalError("""
                ❌ Missing \(key) in Info.plist
                
                Hãy làm theo các bước:
                1. Mở Xcode
                2. Click TARGETS → Chat-Ai (không phải PROJECT)
                3. Tab Info
                4. Add key: \(key)
                   Type: String
                   Value: $(\(key))
                5. Clean Build (⌘ + Shift + K)
                6. Build lại (⌘ + B)
                """)
        }
        return value
    }
    
    // MARK: - Supabase Configuration
    
    static let supabaseURL = infoPlistValue(for: "SUPABASE_URL")
    static let supabaseAnonKey = infoPlistValue(for: "SUPABASE_ANON_KEY")
    
    // MARK: - AI API Configuration
    
    static let aiAPIKey = infoPlistValue(for: "AI_API_KEY")
    
    // MARK: - Transcribe API Configuration
    
    static let transcribeAPIURL = infoPlistValue(for: "TRANSCRIBE_API_URL")
    
    // MARK: - RevenueCat Configuration
    
    static let revenueCatAPIKey = infoPlistValue(for: "REVENUECAT_API_KEY")
    
    // Chọn loại AI service muốn dùng
    enum AIProvider {
        case groq    // Groq API (miễn phí, nhanh)
        case openai  // OpenAI API (cần trả phí)
    }
    
    // Đang dùng provider nào (mặc định là Groq)
    static let aiProvider: AIProvider = .groq
    
    // MARK: - Groq Configuration
    // Cấu hình cho Groq API
    static let groqAPIURL = "https://api.groq.com/openai/v1/chat/completions"
    static let groqModel = "llama-3.1-8b-instant" // Model Llama 3.1 8B (nhanh, miễn phí)
    
    // MARK: - OpenAI Configuration
    // Cấu hình cho OpenAI API (nếu muốn dùng)
    static let openaiAPIURL = "https://api.openai.com/v1/chat/completions"
    static let openaiModel = "gpt-3.5-turbo" // Model GPT-3.5 (rẻ nhất)
    
    // MARK: - User Configuration
    
    /// Lấy user ID hiện tại từ UserDefaults (sau khi đăng nhập)
    /// - Returns: UUID của user đã đăng nhập, hoặc UUID mới nếu chưa đăng nhập
    /// - Note: AuthService sẽ lưu userId vào UserDefaults sau khi đăng nhập thành công
    static func getCurrentUserId() -> UUID {
        // Lấy từ UserDefaults (đã được AuthService lưu sau khi đăng nhập)
        if let savedUserId = UserDefaults.standard.string(forKey: "userId"),
           let uuid = UUID(uuidString: savedUserId) {
            return uuid
        }
        
        // Nếu chưa có, tạo mới (không nên xảy ra nếu có auth)
        let newUserId = UUID()
        UserDefaults.standard.set(newUserId.uuidString, forKey: "userId")
        return newUserId
    }
}

