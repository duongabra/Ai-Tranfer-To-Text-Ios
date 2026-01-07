# Chat AI App - Hướng dẫn sử dụng

Ứng dụng chat với AI đơn giản, sử dụng SwiftUI, Supabase và Groq API.

## 📋 Yêu cầu

- Xcode 16.2+
- iOS 18.2+
- Tài khoản Supabase (đã setup)
- API key từ Groq hoặc OpenAI

## 🚀 Cách chạy app

### Bước 1: Lấy API key từ Groq (Miễn phí)

1. Truy cập: https://console.groq.com
2. Đăng ký tài khoản (miễn phí)
3. Vào mục "API Keys"
4. Tạo API key mới và copy

### Bước 2: Thêm API key vào app

1. Mở file `Chat-Ai/Config/AppConfig.swift`
2. Tìm dòng:
```swift
static let aiAPIKey = "" // ← Thêm API key của bạn vào đây
```
3. Paste API key vào giữa hai dấu ngoặc kép:
```swift
static let aiAPIKey = "gsk_xxxxxxxxxxxxx" // ← API key của bạn
```
4. Save file

### Bước 3: Build và chạy

1. Mở file `Chat-Ai.xcodeproj` bằng Xcode
2. Chọn simulator (iPhone 15 Pro hoặc bất kỳ)
3. Nhấn ⌘ + R hoặc nút Play để chạy

## 📁 Cấu trúc project

```
Chat-Ai/
├── Models/                      # Data models
│   ├── Conversation.swift       # Model cho cuộc hội thoại
│   └── Message.swift            # Model cho tin nhắn
│
├── Services/                    # Business logic
│   ├── SupabaseService.swift   # Kết nối Supabase database
│   └── AIService.swift          # Kết nối AI API (Groq/OpenAI)
│
├── ViewModels/                  # State management
│   ├── ConversationListViewModel.swift  # Logic cho danh sách chat
│   └── ChatViewModel.swift      # Logic cho màn hình chat
│
├── Views/                       # UI components
│   ├── ConversationListView.swift  # Màn hình danh sách
│   └── ChatView.swift           # Màn hình chat
│
├── Config/                      # Configuration
│   └── AppConfig.swift          # API keys và settings
│
├── Chat_AiApp.swift            # Entry point
└── ContentView.swift           # Root view
```

## 🎯 Tính năng

- ✅ Tạo cuộc hội thoại mới
- ✅ Chat với AI (Groq hoặc OpenAI)
- ✅ Lưu lịch sử chat vào Supabase
- ✅ Xóa cuộc hội thoại
- ✅ Pull to refresh
- ✅ Swipe to delete
- ✅ UI đơn giản, dễ hiểu

## 🔧 Cấu hình nâng cao

### Đổi sang OpenAI API

Nếu muốn dùng OpenAI thay vì Groq:

1. Mở `AppConfig.swift`
2. Thay đổi:
```swift
static let aiProvider: AIProvider = .openai  // Đổi từ .groq sang .openai
```
3. Thêm OpenAI API key vào `aiAPIKey`

### Thay đổi AI model

**Groq models** (trong `AppConfig.swift`):
```swift
static let groqModel = "llama-3.1-8b-instant"  // Nhanh nhất
// Hoặc:
// "llama-3.1-70b-versatile"  // Thông minh hơn nhưng chậm hơn
// "mixtral-8x7b-32768"       // Context dài
```

**OpenAI models**:
```swift
static let openaiModel = "gpt-3.5-turbo"  // Rẻ nhất
// Hoặc:
// "gpt-4"                    // Thông minh nhất nhưng đắt
// "gpt-4-turbo"              // Cân bằng
```

## 📚 Giải thích code cho người mới

### 1. Models (Conversation.swift, Message.swift)
- **Mục đích**: Định nghĩa cấu trúc dữ liệu
- **Identifiable**: Để SwiftUI phân biệt các item
- **Codable**: Để chuyển đổi giữa Swift object và JSON
- **CodingKeys**: Map tên property Swift (camelCase) với database column (snake_case)

### 2. Services (SupabaseService.swift, AIService.swift)
- **Actor**: Đảm bảo thread-safe khi dùng async/await
- **Singleton pattern**: Chỉ có 1 instance trong app
- **async/await**: Xử lý bất đồng bộ (gọi API)
- **URLSession**: Gọi HTTP requests

### 3. ViewModels
- **@MainActor**: Chạy trên main thread (cần cho UI)
- **ObservableObject**: Cho phép SwiftUI observe changes
- **@Published**: Khi giá trị thay đổi, UI tự động update

### 4. Views
- **@StateObject**: Tạo và giữ ViewModel
- **@State**: Lưu state local của view
- **@FocusState**: Quản lý focus của text field
- **NavigationStack**: Điều hướng giữa màn hình
- **List**: Hiển thị danh sách
- **ScrollView**: Scroll content

## ⚠️ Lưu ý

1. **API Keys**: Không nên commit API keys lên Git. Trong app thật nên dùng environment variables.
2. **Authentication**: App này chưa có authentication thật, chỉ dùng user_id cố định.
3. **Error handling**: Đã có basic error handling, có thể cải thiện thêm.
4. **UI**: UI đơn giản để học, có thể customize thêm.

## 🐛 Troubleshooting

### Lỗi "Không thể kết nối đến server"
- Kiểm tra internet
- Kiểm tra Supabase URL và API key trong `AppConfig.swift`

### Lỗi "Chưa có API key"
- Thêm Groq API key vào `AppConfig.swift`

### App crash khi build
- Clean build folder: ⌘ + Shift + K
- Rebuild: ⌘ + B

### Không thấy dữ liệu
- Kiểm tra Supabase RLS policies đã tắt chưa
- Kiểm tra table names đúng chưa: `conversations`, `messages`

## 📖 Tài liệu tham khảo

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Supabase Docs](https://supabase.com/docs)
- [Groq API Docs](https://console.groq.com/docs)
- [Swift Async/Await](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

## 🎓 Học tiếp

Sau khi hiểu code này, bạn có thể:
1. Thêm authentication thật (Supabase Auth)
2. Thêm tính năng gửi hình ảnh
3. Thêm streaming response (AI trả lời từng từ)
4. Thêm dark mode
5. Thêm settings screen
6. Export chat history

---

**Chúc bạn học tốt! 🚀**

Nếu có thắc mắc, hãy đọc kỹ comments trong code, mỗi dòng đều có giải thích chi tiết.

