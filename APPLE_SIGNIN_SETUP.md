# 🍎 Apple Sign In Setup Guide

## 📋 Tổng quan
Hướng dẫn cấu hình **Sign in with Apple** cho app Chat-Ai với Supabase backend.

---

## 🔧 Bước 1: Cấu hình trong Xcode

### 1.1. Thêm Sign in with Apple Capability
1. Mở project trong Xcode
2. Chọn target **Chat-Ai**
3. Vào tab **Signing & Capabilities**
4. Click **+ Capability**
5. Tìm và thêm **Sign in with Apple**

### 1.2. Kiểm tra Entitlements File
File `Chat-Ai.entitlements` đã được tạo với nội dung:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

### 1.3. Kiểm tra Bundle Identifier
- Đảm bảo Bundle Identifier trong Xcode khớp với App ID trên Apple Developer Portal
- Ví dụ: `com.yourcompany.chatai`

---

## 🌐 Bước 2: Cấu hình Apple Developer Portal

### 2.1. Tạo App ID (nếu chưa có)
1. Truy cập [Apple Developer Portal](https://developer.apple.com/account/)
2. Vào **Certificates, Identifiers & Profiles**
3. Chọn **Identifiers** → Click **+**
4. Chọn **App IDs** → Continue
5. Nhập:
   - **Description**: Chat-Ai
   - **Bundle ID**: `com.yourcompany.chatai` (Explicit)
6. Trong **Capabilities**, check ✅ **Sign in with Apple**
7. Click **Continue** → **Register**

### 2.2. Tạo Service ID (cho Supabase)
1. Vào **Identifiers** → Click **+**
2. Chọn **Services IDs** → Continue
3. Nhập:
   - **Description**: Chat-Ai Web Service
   - **Identifier**: `com.yourcompany.chatai.service`
4. Check ✅ **Sign in with Apple**
5. Click **Configure** bên cạnh "Sign in with Apple"
6. Chọn **Primary App ID**: `com.yourcompany.chatai`
7. Thêm **Domains and Subdomains**:
   - `<your-project-ref>.supabase.co`
8. Thêm **Return URLs**:
   - `https://<your-project-ref>.supabase.co/auth/v1/callback`
9. Click **Save** → **Continue** → **Register**

### 2.3. Tạo Private Key
1. Vào **Keys** → Click **+**
2. Nhập **Key Name**: Chat-Ai Apple Sign In Key
3. Check ✅ **Sign in with Apple**
4. Click **Configure** → Chọn Primary App ID
5. Click **Save** → **Continue** → **Register**
6. **Download** file `.p8` (chỉ tải được 1 lần!)
7. Lưu lại:
   - **Key ID** (ví dụ: `ABC123DEFG`)
   - **Team ID** (ở góc trên bên phải, ví dụ: `XYZ456HIJK`)

---

## 🗄️ Bước 3: Cấu hình Supabase

### 3.1. Enable Apple Provider
1. Truy cập [Supabase Dashboard](https://app.supabase.com/)
2. Chọn project của bạn
3. Vào **Authentication** → **Providers**
4. Tìm **Apple** → Click để mở rộng
5. Enable **Apple enabled**

### 3.2. Điền thông tin
- **Services ID**: `com.yourcompany.chatai.service` (từ bước 2.2)
- **Team ID**: `XYZ456HIJK` (từ bước 2.3)
- **Key ID**: `ABC123DEFG` (từ bước 2.3)
- **Secret Key**: Mở file `.p8` và copy toàn bộ nội dung (bao gồm cả header và footer):
  ```
  -----BEGIN PRIVATE KEY-----
  MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
  -----END PRIVATE KEY-----
  ```

### 3.3. Save Configuration
Click **Save** để lưu cấu hình.

---

## 📱 Bước 4: Test trên Device/Simulator

### 4.1. Test trên Simulator
- Apple Sign In **hoạt động** trên iOS Simulator (iOS 13.5+)
- Cần đăng nhập Apple ID trong **Settings** → **Apple ID**

### 4.2. Test trên Real Device
- Cần đăng nhập Apple ID
- Device phải có iOS 13.0+

### 4.3. Test Flow
1. Mở app → Tap "Sign in with Apple"
2. Popup Apple Sign In xuất hiện
3. Chọn tài khoản Apple ID hoặc nhập thông tin
4. Chọn chia sẻ email (hoặc ẩn email)
5. Xác nhận Face ID/Touch ID
6. App nhận được token và đăng nhập thành công

---

## 🐛 Troubleshooting

### Lỗi: "Invalid client"
- **Nguyên nhân**: Service ID hoặc Bundle ID không khớp
- **Giải pháp**: Kiểm tra lại Service ID trong Supabase và Apple Developer Portal

### Lỗi: "Invalid grant"
- **Nguyên nhân**: Private Key không đúng hoặc đã hết hạn
- **Giải pháp**: Tạo lại Private Key và cập nhật trong Supabase

### Lỗi: "Redirect URI mismatch"
- **Nguyên nhân**: Return URL không khớp
- **Giải pháp**: Đảm bảo Return URL là `https://<your-project-ref>.supabase.co/auth/v1/callback`

### Apple Sign In không hiện popup
- **Nguyên nhân**: Chưa thêm capability hoặc chưa đăng nhập Apple ID
- **Giải pháp**: 
  - Kiểm tra Signing & Capabilities trong Xcode
  - Đăng nhập Apple ID trong Settings (Simulator/Device)

---

## 📚 Tài liệu tham khảo
- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Supabase Apple Auth Guide](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [ASAuthorizationController Documentation](https://developer.apple.com/documentation/authenticationservices/asauthorizationcontroller)

---

## ✅ Checklist
- [ ] Thêm Sign in with Apple capability trong Xcode
- [ ] Tạo App ID trên Apple Developer Portal
- [ ] Tạo Service ID với Return URL đúng
- [ ] Tạo Private Key và lưu lại Key ID, Team ID
- [ ] Enable Apple provider trong Supabase
- [ ] Điền đầy đủ thông tin (Service ID, Team ID, Key ID, Secret Key)
- [ ] Test trên Simulator/Device
- [ ] Verify user được tạo trong Supabase Authentication

---

**Hoàn thành!** 🎉 Apple Sign In đã sẵn sàng sử dụng!

