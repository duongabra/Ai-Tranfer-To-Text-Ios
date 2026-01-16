# Apple Review Fixes - Hướng dẫn sửa các vấn đề từ Apple Review

## ✅ Đã Fix Trong Code

### 1. ✅ Terms of Service và Privacy Policy Links
- **File**: `SettingsView.swift`, `PaywallView.swift`
- **Fix**: Đã sửa `openURL()` để mở links trong Safari với options đúng
- **Status**: ✅ Hoàn thành

### 2. ✅ Delete Account Feature
- **File**: `SettingsView.swift`, `DeleteAccountConfirmationView.swift` (mới)
- **Fix**: Đã thêm tính năng xóa account vào Settings
- **Status**: ✅ Hoàn thành

### 3. ✅ Subscription Terms trong PaywallView
- **File**: `PaywallView.swift`
- **Fix**: Đã thêm subscription details và Terms/Privacy links vào PaywallView
- **Status**: ✅ Hoàn thành

### 4. ✅ Subscription Products Loading
- **File**: `StoreKitService.swift`, `PaywallView.swift`
- **Fix**: Đã thêm error handling và logging cho subscription loading
- **Status**: ✅ Hoàn thành

## ⚠️ Cần Fix Trong App Store Connect

### 1. ⚠️ App Name và Display Name
**Vấn đề**: App name không khớp
- Marketplace: "Free Chat For Every One"
- Device: "Chat-AI"

**Cách fix**:
1. Vào App Store Connect → My Apps → Chọn app
2. Vào "App Information"
3. Đổi "Name" thành tên không có "Free" (ví dụ: "Chat For Everyone" hoặc "Chat AI")
4. Hoặc đổi Display Name trong Xcode project để khớp với App Store name

**Trong Xcode**:
- Mở project → Target → General → Display Name
- Đổi thành "Free Chat For Every One" (hoặc tên bạn muốn hiển thị)

### 2. ⚠️ In-App Purchase Metadata
**Vấn đề**: Metadata có placeholder content

**Cách fix**:
1. Vào App Store Connect → My Apps → Chọn app
2. Vào "Features" → "In-App Purchases"
3. Click vào từng subscription product
4. Click "Edit In-App Purchase Details"
5. Điền đầy đủ:
   - **Name**: Tên gói (ví dụ: "Weekly Pro", "Monthly Pro")
   - **Description**: Mô tả chi tiết về gói subscription
   - **Review Information**: Screenshot và notes cho reviewer
6. Click "Save"
7. Click "Submit for Review" ở trang App Version Information

### 3. ⚠️ Promotional Image
**Vấn đề**: Promotional image giống app icon

**Cách fix**:
1. Vào App Store Connect → My Apps → Chọn app
2. Vào "Features" → "In-App Purchases"
3. Click vào subscription product
4. Xóa hoặc thay đổi promotional image
5. Nếu không muốn promote, có thể xóa promotional image

### 4. ⚠️ Support URL
**Vấn đề**: Support URL không có thông tin support

**Cách fix**:
1. Tạo trang support trên website `https://quick-vid-read.lovable.app/support`
2. Hoặc cập nhật trang hiện tại để có thông tin support
3. Vào App Store Connect → My Apps → Chọn app
4. Vào "App Information"
5. Cập nhật "Support URL" thành URL có thông tin support

## 🔍 Cần Kiểm Tra Thêm

### 1. Video Analysis Bug trên iPad
**Vấn đề**: App hiển thị error khi analyze video trên iPad

**Cần kiểm tra**:
- Test trên iPad simulator/device
- Kiểm tra `TranscribeService.swift` xem có vấn đề gì với iPad không
- Kiểm tra file handling có support iPad không
- Có thể cần thêm iPad-specific handling

**File cần kiểm tra**: `TranscribeService.swift`, `UploadFileModal.swift`

### 2. Subscription Products Loading trên iPad
**Vấn đề**: Subscription products không load được

**Cần kiểm tra**:
- Test trên iPad với sandbox account
- Kiểm tra App Store Connect configuration
- Đảm bảo products đã được submit và approved
- Kiểm tra Paid Apps Agreement đã được accept chưa

## 📝 Checklist Trước Khi Resubmit

- [ ] Đổi app name trong App Store Connect (xóa "Free")
- [ ] Hoặc đổi Display Name trong Xcode để khớp
- [ ] Update In-App Purchase metadata (Name, Description)
- [ ] Xóa/thay đổi promotional image
- [ ] Tạo và cập nhật Support URL
- [ ] Test app trên iPad
- [ ] Test subscription purchase flow trên iPad
- [ ] Test video analysis trên iPad
- [ ] Đảm bảo Terms và Privacy links hoạt động
- [ ] Test Delete Account feature
- [ ] Verify Paid Apps Agreement đã được accept

## 🚀 Sau Khi Fix Xong

1. Build app mới với các fixes
2. Upload build mới lên App Store Connect
3. Update app version information
4. Submit for review lại
5. Reply to Apple trong App Store Connect với thông tin về các fixes đã thực hiện
