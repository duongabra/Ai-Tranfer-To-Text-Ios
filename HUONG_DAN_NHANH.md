# 🚀 Hướng dẫn chạy app nhanh (5 phút)

## Bước 1: Lấy API key miễn phí từ Groq

1. Mở trình duyệt, vào: **https://console.groq.com**
2. Nhấn "Sign Up" (đăng ký) - dùng email hoặc Google
3. Sau khi đăng nhập, nhấn "API Keys" ở menu bên trái
4. Nhấn "Create API Key"
5. Copy API key (dạng: `gsk_xxxxxxxxxx`)

## Bước 2: Thêm API key vào code

1. Trong Cursor/Xcode, mở file: **`Chat-Ai/Config/AppConfig.swift`**
2. Tìm dòng số 18:
   ```swift
   static let aiAPIKey = ""
   ```
3. Paste API key vào giữa hai dấu `""`:
   ```swift
   static let aiAPIKey = "gsk_xxxxxxxxxx"
   ```
4. Save (⌘ + S)

## Bước 3: Chạy app

1. Mở file **`Chat-Ai.xcodeproj`** bằng Xcode (double click)
2. Chọn simulator ở góc trên (ví dụ: iPhone 15 Pro)
3. Nhấn nút ▶️ Play hoặc ⌘ + R
4. Đợi app build và chạy (lần đầu sẽ hơi lâu)

## Bước 4: Test app

1. App mở lên, nhấn nút **+** ở góc phải trên
2. Nhập tiêu đề (ví dụ: "Test chat"), nhấn **Tạo**
3. Tap vào cuộc hội thoại vừa tạo
4. Gõ tin nhắn: "Xin chào, bạn là ai?"
5. Nhấn nút gửi (mũi tên lên)
6. Đợi AI trả lời (khoảng 2-3 giây)

## ✅ Xong!

Nếu thấy AI trả lời, nghĩa là app đã hoạt động thành công! 🎉

---

## 🐛 Gặp lỗi?

### "Chưa có API key"
→ Kiểm tra lại Bước 2, đảm bảo đã paste API key đúng

### "Không thể kết nối đến server"
→ Kiểm tra internet, hoặc Supabase URL trong AppConfig.swift

### App crash
→ Clean build: ⌘ + Shift + K, rồi build lại: ⌘ + B

---

## 📚 Muốn hiểu code?

Đọc file **README.md** để hiểu chi tiết về:
- Cấu trúc project
- Giải thích từng file
- Cách customize

Mỗi file code đều có **comment chi tiết bằng tiếng Việt**, hãy đọc kỹ!

---

**Chúc bạn thành công! 💪**

