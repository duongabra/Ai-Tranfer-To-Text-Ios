# 📖 Giải thích code chi tiết cho người mới

## 🏗️ Kiến trúc app (MVVM Pattern)

```
┌─────────────────────────────────────────────────┐
│                    Views                        │  ← UI (SwiftUI)
│  ConversationListView, ChatView                 │
└─────────────────┬───────────────────────────────┘
                  │ gọi methods
                  ▼
┌─────────────────────────────────────────────────┐
│                 ViewModels                      │  ← Logic & State
│  ConversationListViewModel, ChatViewModel       │
└─────────────────┬───────────────────────────────┘
                  │ gọi services
                  ▼
┌─────────────────────────────────────────────────┐
│                  Services                       │  ← Business Logic
│  SupabaseService, AIService                     │
└─────────────────┬───────────────────────────────┘
                  │ gọi APIs
                  ▼
┌─────────────────────────────────────────────────┐
│            External APIs                        │
│  Supabase Database, Groq/OpenAI API             │
└─────────────────────────────────────────────────┘
```

## 🔄 Flow khi gửi tin nhắn

```
1. User gõ tin nhắn trong ChatView
   ↓
2. Tap nút gửi → gọi viewModel.sendMessage()
   ↓
3. ChatViewModel xử lý:
   ├─ Lưu message của user vào Supabase
   ├─ Gửi tất cả messages đến AI API
   ├─ Nhận response từ AI
   ├─ Lưu response vào Supabase
   └─ Update UI
   ↓
4. User thấy phản hồi của AI
```

## 📝 Giải thích các khái niệm Swift

### 1. Struct vs Class

```swift
// Struct (dùng cho Models)
struct Message {
    let id: UUID
    let content: String
}
// ✅ Value type: copy khi assign
// ✅ Immutable by default
// ✅ Dùng cho data models

// Class (dùng cho ViewModels)
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
}
// ✅ Reference type: share khi assign
// ✅ Có thể thay đổi
// ✅ Dùng cho logic và state management
```

### 2. Property Wrappers

```swift
// @Published - Thông báo khi giá trị thay đổi
@Published var messages: [Message] = []
// Khi messages thay đổi → UI tự động update

// @StateObject - Tạo và giữ object
@StateObject private var viewModel = ChatViewModel()
// ViewModel sống suốt lifecycle của View

// @State - Lưu state local
@State private var inputText = ""
// Khi inputText thay đổi → View re-render

// @FocusState - Quản lý focus
@FocusState private var isInputFocused: Bool
// Control keyboard show/hide
```

### 3. Async/Await

```swift
// Cách cũ (callback hell):
fetchData { result in
    processData(result) { processed in
        saveData(processed) { saved in
            // ...
        }
    }
}

// Cách mới (async/await):
let result = await fetchData()
let processed = await processData(result)
let saved = await saveData(processed)
// ✅ Dễ đọc, dễ hiểu hơn
```

### 4. Actor

```swift
actor SupabaseService {
    // Actor đảm bảo thread-safe
    // Chỉ 1 task có thể access cùng lúc
}
```

### 5. Codable

```swift
struct Message: Codable {
    let id: UUID
    let content: String
}

// Encode: Swift object → JSON
let jsonData = try JSONEncoder().encode(message)

// Decode: JSON → Swift object
let message = try JSONDecoder().decode(Message.self, from: jsonData)
```

## 🎨 SwiftUI Components

### 1. List

```swift
List {
    ForEach(conversations) { conversation in
        Text(conversation.title)
    }
}
// Hiển thị danh sách scrollable
```

### 2. NavigationStack

```swift
NavigationStack {
    List { ... }
        .navigationTitle("Chat AI")
}
// Cho phép navigate giữa màn hình
```

### 3. Sheet

```swift
.sheet(isPresented: $showingSheet) {
    NewConversationSheet()
}
// Hiển thị modal từ dưới lên
```

### 4. Task

```swift
.task {
    await loadData()
}
// Chạy async code khi view xuất hiện
```

## 🔍 Đọc code như thế nào?

### Bước 1: Bắt đầu từ entry point

```
Chat_AiApp.swift (entry point)
    ↓
ContentView.swift (root view)
    ↓
ConversationListView.swift (màn hình chính)
```

### Bước 2: Hiểu flow một tính năng

**Ví dụ: Tạo conversation mới**

1. **View**: `ConversationListView.swift`

   - User tap nút "+"
   - Hiển thị sheet `NewConversationSheet`
   - User nhập title và tap "Tạo"

2. **ViewModel**: `ConversationListViewModel.swift`

   - Method `createConversation(title:)` được gọi
   - Gọi service để tạo conversation

3. **Service**: `SupabaseService.swift`

   - Method `createConversation(title:)` được gọi
   - Tạo HTTP POST request đến Supabase
   - Parse response và return Conversation object

4. **View**: Quay lại
   - ViewModel nhận conversation mới
   - Thêm vào array `conversations`
   - SwiftUI tự động update UI

### Bước 3: Debug

```swift
// Thêm print để debug
print("🔍 Messages count: \(messages.count)")
print("📝 Input text: \(inputText)")
print("❌ Error: \(error)")
```

## 💡 Tips học Swift/SwiftUI

### 1. Đọc error messages

```
Error: Cannot find 'viewModel' in scope
→ Bạn chưa khai báo viewModel
→ Thêm: @StateObject private var viewModel = ...
```

### 2. Dùng Xcode autocomplete

- Gõ `view` + Tab → Xcode suggest
- Gõ `.` sau object → xem available methods

### 3. Đọc documentation

- Option + Click vào function/type → xem docs
- Ví dụ: Option + Click vào `List` → hiểu cách dùng

### 4. Thử nghiệm

- Tạo Playground để test code nhỏ
- Thay đổi UI và xem kết quả ngay

## 📚 Các khái niệm quan trọng

### 1. Optionals

```swift
var name: String?  // Có thể là String hoặc nil

// Unwrap an toàn
if let name = name {
    print(name)  // Chỉ chạy nếu name không nil
}

// Nil coalescing
let displayName = name ?? "Guest"  // Dùng "Guest" nếu name là nil
```

### 2. Guard

```swift
guard let name = name else {
    return  // Thoát sớm nếu name là nil
}
// name có thể dùng ở đây
```

### 3. Closures

```swift
// Closure = anonymous function
let numbers = [1, 2, 3, 4]
let doubled = numbers.map { $0 * 2 }  // [2, 4, 6, 8]
```

### 4. Extensions

```swift
extension String {
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}

"Hello".isNotEmpty  // true
```

## 🎯 Bài tập để hiểu sâu hơn

### Level 1: Đọc hiểu

- [ ] Đọc hết comments trong `Message.swift`
- [ ] Đọc hết comments trong `SupabaseService.swift`
- [ ] Hiểu flow trong `sendMessage()` của `ChatViewModel`

### Level 2: Sửa đổi nhỏ

- [ ] Đổi màu bubble của user message (trong `ChatView.swift`)
- [ ] Thêm placeholder khác cho input field
- [ ] Đổi title của navigation bar

### Level 3: Thêm tính năng

- [ ] Thêm nút "Clear all" để xóa tất cả conversations
- [ ] Thêm character count cho input field
- [ ] Thêm timestamp cho mỗi conversation row

### Level 4: Tính năng nâng cao

- [ ] Thêm search bar để tìm conversations
- [ ] Thêm settings screen
- [ ] Thêm dark mode toggle

## 🔗 Resources học thêm

1. **Swift Basics**

   - https://docs.swift.org/swift-book/
   - Học về: Optionals, Closures, Protocols

2. **SwiftUI**

   - https://developer.apple.com/tutorials/swiftui
   - Học về: Views, State, Bindings

3. **Async/Await**

   - https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
   - Học về: Tasks, Actors, async/await

4. **MVVM Pattern**
   - Google: "SwiftUI MVVM tutorial"
   - Hiểu về: Separation of concerns

---

**Đừng vội, học từng bước một! 🚶‍♂️**

Mỗi ngày hiểu thêm một file, một khái niệm là đã tốt rồi.
