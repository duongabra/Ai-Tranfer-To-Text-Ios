# 🔧 Setup Config.xcconfig - Hướng dẫn chi tiết

## 📝 Tổng quan

Project này dùng **`.xcconfig`** file để quản lý API keys và secrets, tương tự **`.env`** trong web development.

**Ưu điểm:**
- ✅ Không commit API keys lên Git
- ✅ Dễ quản lý nhiều môi trường (Dev, Staging, Production)
- ✅ Chuẩn iOS/Xcode

---

## 🚀 Cách setup (Lần đầu)

### Bước 1: Config.xcconfig đã có sẵn

File `Config.xcconfig` đã được tạo với API keys của bạn. Nếu cần thay đổi, mở file và edit:

```
SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_ANON_KEY = your_key_here
AI_API_KEY = your_key_here
```

### Bước 2: Add Config.xcconfig vào Xcode Project

**QUAN TRỌNG:** Bạn cần làm bước này trong Xcode:

1. **Mở Xcode**
2. Click vào **project root** (Chat-Ai - màu xanh) trong Project Navigator
3. Select **project** (không phải target)
4. Chọn tab **Info**
5. Tìm phần **Configurations**:
   ```
   Debug
   Release
   ```
6. Click vào **Debug** → Chọn **Config** từ dropdown
7. Làm tương tự cho **Release**

**Hình ảnh minh họa:**
```
Project Navigator
└── Chat-Ai (project - màu xanh) ← Click vào đây
    └── Info tab
        └── Configurations
            ├── Debug → Config
            └── Release → Config
```

### Bước 3: Build và chạy

1. Clean build: **⌘ + Shift + K**
2. Build: **⌘ + B**
3. Run: **⌘ + R**

---

## 🔍 Kiểm tra setup đúng chưa

### Test 1: Build thành công
- Nếu build thành công → OK
- Nếu lỗi "Missing ... in Info.plist" → Kiểm tra lại Bước 2

### Test 2: App chạy được
- Mở app
- Tạo conversation mới
- Gửi tin nhắn
- Nếu AI trả lời → Setup thành công! ✅

---

## 🐛 Troubleshooting

### Lỗi: "Missing SUPABASE_URL in Info.plist"

**Nguyên nhân:** Chưa add Config.xcconfig vào Xcode project

**Giải pháp:**
1. Làm lại **Bước 2** ở trên
2. Đảm bảo chọn đúng **Config.xcconfig** cho cả Debug và Release
3. Clean build: **⌘ + Shift + K**
4. Build lại: **⌘ + B**

### Lỗi: "Config.xcconfig not found"

**Giải pháp:**
1. Kiểm tra file `Config.xcconfig` có tồn tại ở root project không
2. Nếu không có, copy từ `Config.xcconfig.example`:
   ```bash
   cp Config.xcconfig.example Config.xcconfig
   ```
3. Điền thông tin thật vào `Config.xcconfig`

### App crash khi chạy

**Giải pháp:**
1. Xem logs trong Xcode Console
2. Nếu thấy "Missing ... in Info.plist" → Kiểm tra Config.xcconfig
3. Nếu thấy lỗi khác → Chụp màn hình và debug

---

## 📁 Cấu trúc files

```
Chat-Ai/
├── Config.xcconfig              ← API keys (KHÔNG commit)
├── Config.xcconfig.example      ← Template (commit)
├── .gitignore                   ← Ignore Config.xcconfig
└── Chat-Ai/
    ├── Info.plist               ← Inject từ Config.xcconfig
    └── Config/
        └── AppConfig.swift      ← Đọc từ Info.plist
```

---

## 🔄 Workflow khi làm việc

### Khi clone project lần đầu:

```bash
# 1. Clone project
git clone <repo-url>
cd Chat-Ai

# 2. Copy config từ example
cp Config.xcconfig.example Config.xcconfig

# 3. Edit Config.xcconfig và điền API keys
open Config.xcconfig

# 4. Mở Xcode và setup (Bước 2 ở trên)
open Chat-Ai.xcodeproj

# 5. Build và chạy
```

### Khi thay đổi API keys:

```bash
# 1. Edit Config.xcconfig
open Config.xcconfig

# 2. Clean build
⌘ + Shift + K

# 3. Build lại
⌘ + B
```

---

## 🎯 So sánh với Web Development

| iOS (Xcode) | Web (Node.js) |
|-------------|---------------|
| `Config.xcconfig` | `.env` |
| `Config.xcconfig.example` | `.env.example` |
| `.gitignore` → `Config.xcconfig` | `.gitignore` → `.env` |
| `Info.plist` | - |
| `AppConfig.swift` | `process.env` |

---

## 💡 Tips

1. **Nhiều môi trường:**
   - Tạo `Config.Dev.xcconfig`
   - Tạo `Config.Prod.xcconfig`
   - Switch giữa các configs trong Xcode

2. **Share với team:**
   - Commit `Config.xcconfig.example`
   - Team copy thành `Config.xcconfig` và điền keys của họ

3. **CI/CD:**
   - Tạo `Config.xcconfig` trong CI pipeline
   - Inject từ environment variables

---

## ✅ Checklist

- [ ] File `Config.xcconfig` đã có và chứa API keys đúng
- [ ] File `Info.plist` đã có trong project
- [ ] Config.xcconfig đã được add vào Xcode (Bước 2)
- [ ] Build thành công (⌘ + B)
- [ ] App chạy được và chat với AI thành công
- [ ] File `Config.xcconfig` đã được add vào `.gitignore`

---

**Nếu gặp vấn đề, hãy kiểm tra lại từng bước hoặc xem logs trong Xcode Console!** 🔍

