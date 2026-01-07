# ✅ Checklist - Những việc cần làm

## 🎯 Trước khi chạy app (BẮT BUỘC)

- [ ] **Đăng ký tài khoản Groq** tại https://console.groq.com
- [ ] **Lấy API key** từ Groq console
- [ ] **Thêm API key** vào file `Chat-Ai/Config/AppConfig.swift` (dòng 18)
- [ ] **Build app** trong Xcode (⌘ + B)
- [ ] **Chạy app** trên simulator (⌘ + R)

## 📋 Kiểm tra Supabase

- [x] Đã tạo bảng `conversations` với các cột:
  - `id` (uuid, PK)
  - `user_id` (uuid)
  - `title` (text)
  - `created_at` (timestamp)
  - `updated_at` (timestamp)

- [x] Đã tạo bảng `messages` với các cột:
  - `id` (uuid, PK)
  - `conversation_id` (uuid)
  - `role` (text)
  - `content` (text)
  - `created_at` (timestamp)

- [ ] **Kiểm tra RLS (Row Level Security)**:
  - Vào Supabase Dashboard
  - Chọn bảng `conversations` → RLS → Disable (để test)
  - Chọn bảng `messages` → RLS → Disable (để test)
  - ⚠️ Trong production nên enable RLS với policies đúng

## 🧪 Test app

### Test 1: Tạo conversation
- [ ] Mở app
- [ ] Tap nút "+" ở góc phải
- [ ] Nhập tiêu đề: "Test Chat"
- [ ] Tap "Tạo"
- [ ] ✅ Thấy conversation mới trong danh sách

### Test 2: Chat với AI
- [ ] Tap vào conversation vừa tạo
- [ ] Gõ tin nhắn: "Xin chào"
- [ ] Tap nút gửi (mũi tên)
- [ ] ✅ Thấy tin nhắn của mình
- [ ] ✅ Đợi 2-3 giây thấy AI trả lời

### Test 3: Xem lịch sử
- [ ] Gửi thêm vài tin nhắn
- [ ] Quay lại màn hình chính
- [ ] Vào lại conversation
- [ ] ✅ Thấy tất cả tin nhắn cũ

### Test 4: Xóa conversation
- [ ] Ở màn hình chính
- [ ] Swipe trái vào conversation
- [ ] Tap "Delete"
- [ ] ✅ Conversation biến mất

### Test 5: Pull to refresh
- [ ] Ở màn hình chính
- [ ] Kéo xuống (pull down)
- [ ] ✅ Danh sách refresh

## 🐛 Nếu gặp lỗi

### Lỗi: "Chưa có API key"
```
⚠️ Chưa có API key. Vui lòng thêm API key vào file AppConfig.swift
```
**Giải pháp:**
- Mở `Chat-Ai/Config/AppConfig.swift`
- Tìm dòng: `static let aiAPIKey = ""`
- Thêm API key vào giữa dấu `""`

### Lỗi: "Không thể kết nối đến server"
**Giải pháp:**
1. Kiểm tra internet
2. Kiểm tra Supabase URL trong `AppConfig.swift`
3. Kiểm tra Supabase API key
4. Vào Supabase Dashboard xem database có hoạt động không

### Lỗi: Build failed
**Giải pháp:**
1. Clean build folder: ⌘ + Shift + K
2. Close Xcode
3. Xóa folder `DerivedData`:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Mở lại Xcode và build

### App crash khi mở
**Giải pháp:**
1. Xem logs trong Xcode console
2. Kiểm tra có file nào bị thiếu không
3. Rebuild project

## 📚 Sau khi app chạy thành công

### Đọc tài liệu
- [ ] Đọc `HUONG_DAN_NHANH.md` (5 phút)
- [ ] Đọc `README.md` (15 phút)
- [ ] Đọc `GIAI_THICH_CODE.md` (30 phút)

### Đọc code
- [ ] Đọc `Models/Message.swift` (dễ nhất)
- [ ] Đọc `Models/Conversation.swift`
- [ ] Đọc `Config/AppConfig.swift`
- [ ] Đọc `Services/SupabaseService.swift`
- [ ] Đọc `Services/AIService.swift`
- [ ] Đọc `ViewModels/ConversationListViewModel.swift`
- [ ] Đọc `ViewModels/ChatViewModel.swift`
- [ ] Đọc `Views/ConversationListView.swift`
- [ ] Đọc `Views/ChatView.swift`

### Thử nghiệm
- [ ] Thay đổi màu sắc UI
- [ ] Thay đổi text
- [ ] Thêm print statements để debug
- [ ] Thử break code và fix lại (học từ lỗi)

## 🎓 Học tiếp

### Week 1: Hiểu cơ bản
- [ ] Hiểu MVVM pattern
- [ ] Hiểu SwiftUI basics (View, State, Binding)
- [ ] Hiểu async/await

### Week 2: Customize
- [ ] Thay đổi UI theo ý thích
- [ ] Thêm tính năng nhỏ (character count, timestamps)
- [ ] Thử các AI models khác nhau

### Week 3: Tính năng mới
- [ ] Thêm search bar
- [ ] Thêm settings screen
- [ ] Thêm export chat history

### Week 4: Advanced
- [ ] Thêm authentication thật
- [ ] Thêm image upload
- [ ] Thêm streaming response

## 🎉 Hoàn thành!

Khi bạn check hết tất cả boxes trên, bạn đã:
- ✅ Hiểu cách build một iOS app từ đầu
- ✅ Biết cách làm việc với API
- ✅ Biết cách dùng database
- ✅ Hiểu SwiftUI và MVVM
- ✅ Sẵn sàng học các tính năng nâng cao hơn

**Chúc mừng bạn! 🎊**

---

## 📞 Cần giúp đỡ?

1. Đọc lại comments trong code
2. Đọc error messages cẩn thận
3. Google error message
4. Hỏi ChatGPT/Claude về lỗi cụ thể
5. Xem Swift documentation

**Đừng bỏ cuộc! Mọi developer đều gặp lỗi, quan trọng là học cách fix. 💪**

