# 🔄 Auto-Refresh Token - Giải thích

## 📌 Vấn đề trước đây:

- Mỗi request đến Supabase đều gọi `refreshAccessTokenIfNeeded()` → **Tốn tài nguyên**
- User bị logout bất ngờ khi token hết hạn (sau 1 giờ)

---

## ✅ Giải pháp mới:

### 🎯 Cách hoạt động:

```
App Launch (đăng nhập thành công)
    ↓
Lưu access token + refresh token + expiration date
    ↓
Bắt đầu background timer (check mỗi 5 phút)
    ↓
Timer kiểm tra: Token còn dưới 10 phút?
    ├─ Không → Tiếp tục đợi
    └─ Có → Tự động refresh token
        ↓
    Lưu token mới + expiration date mới
        ↓
    Tiếp tục timer
```

### 📋 Các thành phần:

#### 1. **AuthService.swift**

**Thêm:**
- `refreshTimer: Task<Void, Never>?` - Background timer
- `startAutoRefreshTimer()` - Bắt đầu timer khi đăng nhập
- `stopAutoRefreshTimer()` - Dừng timer khi đăng xuất
- `shouldRefreshToken()` - Kiểm tra xem có cần refresh không
- `checkAndRefreshTokenIfNeeded()` - Kiểm tra khi app khởi động

**Logic:**
- Khi `saveSession()` được gọi (sau đăng nhập):
  - Lưu `accessTokenExpirationDate` (1 giờ từ bây giờ)
  - Bắt đầu background timer
- Timer chạy mỗi 5 phút:
  - Kiểm tra xem token còn dưới 10 phút không
  - Nếu có → Tự động refresh token
  - Nếu refresh thất bại → Dừng timer (user cần đăng nhập lại)
- Khi `signOut()`:
  - Hủy timer
  - Xóa tất cả token và expiration date

#### 2. **SupabaseService.swift**

**Thay đổi:**
- Xóa `refreshAccessTokenIfNeeded()` khỏi `createAuthenticatedRequest()`
- Chỉ lấy token từ `AuthService.shared.getAccessToken()` (đã được auto-refresh)

**Lợi ích:**
- Không gửi thêm request mỗi lần gọi API
- Token luôn fresh nhờ background timer

#### 3. **Chat_AiApp.swift**

**Thêm:**
- `.task { await AuthService.shared.checkAndRefreshTokenIfNeeded() }` khi app khởi động
- Kiểm tra và refresh token ngay khi mở app (nếu cần)

---

## 🚀 Lợi ích:

### ✅ Hiệu quả:
- Không tốn tài nguyên: Chỉ refresh khi cần (mỗi 1 giờ)
- Không gửi thêm request mỗi lần gọi API

### ✅ Trải nghiệm người dùng:
- User không bị logout bất ngờ
- Token tự động refresh trong background
- "Token infinite" cho testing

### ✅ Bảo mật:
- Token vẫn có thời gian hết hạn (1 giờ)
- Refresh token được lưu an toàn trong UserDefaults
- Nếu refresh thất bại → User phải đăng nhập lại

---

## 🧪 Test:

### 1. Đăng nhập:
```
✅ Saved refresh token
✅ Access token will expire at: 2025-01-08 12:00:00
✅ Đã bắt đầu auto-refresh timer
```

### 2. Sau 50 phút (token còn 10 phút):
```
🔄 Token sắp hết hạn, đang refresh...
✅ Access token refreshed successfully (expires at: 2025-01-08 13:00:00)
```

### 3. Đăng xuất:
```
✅ Đã dừng auto-refresh timer
✅ Đăng xuất thành công
```

---

## 🛡️ Xử lý lỗi 401 Unauthorized:

### Khi nào xảy ra?
- Token hết hạn mà background timer chưa kịp refresh
- Refresh token thất bại
- Token bị revoke từ server

### Cách xử lý:

```
Request → Supabase trả về 401
    ↓
SupabaseService throw SupabaseError.unauthorized
    ↓
ViewModel catch error và kiểm tra
    ↓
Gọi AuthService.shared.handleUnauthorizedError()
    ↓
Tự động logout user
    ↓
Gửi NotificationCenter.userDidLogout
    ↓
AuthViewModel nhận notification
    ↓
Set currentUser = nil
    ↓
UI tự động chuyển về LoginView
```

### Code example:

**SupabaseService.swift:**
```swift
// Kiểm tra 401 Unauthorized
if httpResponse.statusCode == 401 {
    throw SupabaseError.unauthorized
}
```

**ConversationListViewModel.swift:**
```swift
catch {
    // Kiểm tra nếu là lỗi 401 → Logout
    if let supabaseError = error as? SupabaseError, 
       supabaseError == .unauthorized {
        await AuthService.shared.handleUnauthorizedError()
        return
    }
    // Xử lý lỗi khác...
}
```

**AuthService.swift:**
```swift
func handleUnauthorizedError() async {
    try await signOut()
    // Gửi notification để UI update
    NotificationCenter.default.post(name: .userDidLogout, object: nil)
}
```

**AuthViewModel.swift:**
```swift
init() {
    // Lắng nghe notification
    NotificationCenter.default.addObserver(
        forName: .userDidLogout,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.handleForcedLogout()
    }
}

private func handleForcedLogout() {
    currentUser = nil
    errorMessage = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
}
```

---

## 📝 Notes:

- **Timer interval**: 5 phút (có thể điều chỉnh nếu cần)
- **Refresh threshold**: 10 phút trước khi hết hạn (có thể điều chỉnh)
- **Token lifetime**: 1 giờ (mặc định của Supabase)
- **Fallback**: Nếu refresh thất bại hoặc 401 → Tự động logout user

---

## 🔧 Nếu muốn thay đổi:

### Thay đổi thời gian check:
```swift
// Trong startAutoRefreshTimer()
try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000) // 10 minutes thay vì 5
```

### Thay đổi threshold refresh:
```swift
// Trong shouldRefreshToken()
return timeUntilExpiration < 300 // 5 minutes thay vì 10
```

### Thay đổi token lifetime:
```swift
// Trong saveSession() và refreshAccessToken()
let expirationDate = Date().addingTimeInterval(7200) // 2 hours thay vì 1
```

