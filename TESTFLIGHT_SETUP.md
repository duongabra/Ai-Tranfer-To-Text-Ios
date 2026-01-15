# Hướng dẫn Setup TestFlight - Chi tiết từng bước

## 📋 Tổng quan

Project hiện tại:

- **Bundle ID**: `com.whales.Chat-Ai`
- **Version**: 1.0
- **Build**: 1

---

## BƯỚC 2: Kiểm tra và chuẩn bị Project trong Xcode

### 2.1. Mở project trong Xcode

```bash
cd /Users/duong/Desktop/code/Chat-Ai
open Chat-Ai.xcodeproj
```

### 2.2. Kiểm tra Signing & Capabilities

1. Chọn project **Chat-Ai** ở sidebar trái
2. Chọn target **Chat-Ai**
3. Vào tab **Signing & Capabilities**
4. Đảm bảo:
   - ✅ **Automatically manage signing** được bật
   - ✅ **Team** đã chọn đúng team của bạn (Apple Developer account)
   - ✅ **Bundle Identifier**: `com.whales.Chat-Ai`
   - ✅ **Provisioning Profile** được tạo tự động

### 2.3. Kiểm tra Version & Build Number

1. Vào tab **General**
2. Kiểm tra:
   - **Version**: `1.0` (hoặc version bạn muốn)
   - **Build**: `1` (sẽ tăng mỗi lần upload build mới)

### 2.4. Chọn Device để Archive

- Chọn **Any iOS Device** hoặc **Generic iOS Device** ở toolbar trên cùng
- KHÔNG chọn simulator (simulator không thể archive)

---

## BƯỚC 3: Archive và Upload Build

### 3.1. Archive App

#### Bước 3.1.1: Chọn Device đúng

1. Mở Xcode và project **Chat-Ai**
2. Ở toolbar trên cùng, tìm dropdown device (bên cạnh nút Play/Stop)
3. Click vào dropdown và chọn:
   - ✅ **Any iOS Device** (khuyến nghị)
   - ✅ **Generic iOS Device**
   - ❌ KHÔNG chọn simulator (ví dụ: "iPhone 15 Pro Simulator")

#### Bước 3.1.2: Archive

1. Vào menu trên cùng: **Product > Archive**
   - Hoặc nhấn phím tắt: `Cmd + Shift + B` (Build for Archive)
   - Sau đó: **Product > Archive**
2. Xcode sẽ bắt đầu build project
3. Đợi quá trình build hoàn tất:
   - Có thể mất **2-5 phút** tùy kích thước project
   - Xem progress ở thanh progress bar phía trên
   - Nếu có lỗi, sửa lỗi và archive lại

#### Bước 3.1.3: Organizer tự động mở

- Sau khi archive thành công, cửa sổ **Organizer** sẽ tự động mở
- Nếu không tự mở: **Window > Organizer** (hoặc `Cmd + Shift + 9`)
- Bạn sẽ thấy archive vừa tạo với:
  - Tên app: **Chat-Ai**
  - Version: **1.0**
  - Build: **1**
  - Ngày giờ archive

---

### 3.2. Validate Archive (Tùy chọn nhưng khuyến nghị)

**Lưu ý**: Bước này giúp phát hiện lỗi trước khi upload, tiết kiệm thời gian.

1. Trong cửa sổ **Organizer**, chọn archive vừa tạo (click vào nó)
2. Click nút **Validate App** (màu xanh, ở bên phải)
3. Màn hình **Validate App** hiện ra:
   - Chọn **App Store Connect**
   - Click **Next**
4. Chọn **Automatically manage signing** (khuyến nghị)
   - Hoặc chọn **Manual** nếu bạn tự quản lý certificates
   - Click **Next**
5. Xem lại thông tin:
   - App name
   - Bundle ID: `com.whales.Chat-Ai`
   - Version & Build
   - Click **Validate**
6. Đợi validation hoàn tất:
   - ✅ **Success**: Không có lỗi, có thể upload
   - ❌ **Failed**: Xem lỗi và sửa, sau đó archive lại

**Nếu validation thành công**: Tiếp tục bước 3.3  
**Nếu validation thất bại**: Sửa lỗi và archive lại từ đầu

---

### 3.3. Distribute App (Upload lên App Store Connect)

#### Bước 3.3.1: Bắt đầu Distribute

1. Trong cửa sổ **Organizer**, chọn archive vừa tạo
2. Click nút **Distribute App** (màu xanh, ở bên phải)
3. Màn hình **Distribute App** hiện ra

#### Bước 3.3.2: Chọn phương thức phân phối

1. Chọn **App Store Connect**
   - Đây là option để upload lên TestFlight
2. Click **Next**

#### Bước 3.3.3: Chọn phương thức upload

1. Chọn **Upload**
   - Option này sẽ upload build lên App Store Connect
   - Không chọn "Export" (dùng để export file .ipa)
2. Click **Next**

#### Bước 3.3.4: Chọn Distribution Options

1. Màn hình **Distribution Options** hiện ra:
   - ✅ **Upload your app's symbols** (khuyến nghị) - Giúp debug crash reports
   - ✅ **Manage Version and Build Number** (khuyến nghị) - Tự động quản lý version
2. Giữ nguyên các option mặc định
3. Click **Next**

#### Bước 3.3.5: Chọn Signing Method

1. Chọn **Automatically manage signing** (khuyến nghị)
   - Xcode sẽ tự động tạo và quản lý certificates/profiles
   - Hoặc chọn **Manual** nếu bạn tự quản lý
2. Click **Next**

#### Bước 3.3.6: Xem lại thông tin

1. Màn hình **Review** hiện ra, kiểm tra:
   - ✅ **App**: Chat-Ai
   - ✅ **Bundle ID**: com.whales.Chat-Ai
   - ✅ **Version**: 1.0
   - ✅ **Build**: 1
   - ✅ **Distribution Certificate**: (tự động)
   - ✅ **Provisioning Profile**: (tự động)
2. Nếu mọi thứ đúng, click **Upload**

#### Bước 3.3.7: Đợi Upload hoàn tất

1. Xcode sẽ bắt đầu upload build:
   - Có thể mất **5-15 phút** tùy kích thước app
   - Xem progress ở thanh progress bar
   - KHÔNG đóng Xcode trong lúc này
2. Khi upload thành công:
   - ✅ Màn hình **Upload Successful** hiện ra
   - Click **Done**
   - Build đã được upload lên App Store Connect

#### Bước 3.3.8: Kiểm tra trong App Store Connect

1. Vào: https://appstoreconnect.apple.com
2. Đăng nhập bằng Apple Developer account
3. Vào **My Apps** > Chọn app **Chat-Ai**
4. Vào tab **TestFlight**
5. Build sẽ xuất hiện trong phần **Builds**:
   - Trạng thái: **Processing** (đang xử lý)
   - Đợi **10-30 phút** để Apple process build
   - Sau đó sẽ chuyển sang **Ready to Submit** hoặc **Ready to Test**

---

## ⚠️ Lưu ý quan trọng khi Archive & Upload

### Lỗi thường gặp:

1. **"No signing certificate found"**

   - Giải pháp: Vào **Signing & Capabilities** trong Xcode, chọn đúng Team

2. **"Bundle identifier already exists"**

   - Giải pháp: Đảm bảo Bundle ID `com.whales.Chat-Ai` đã được tạo trong App Store Connect

3. **"Invalid Bundle"**

   - Giải pháp: Kiểm tra lại Info.plist, đảm bảo không có key nào bị thiếu

4. **Upload failed**
   - Giải pháp: Kiểm tra kết nối internet, thử lại

### Tips:

- ✅ Luôn validate trước khi upload (tiết kiệm thời gian)
- ✅ Đảm bảo internet ổn định khi upload
- ✅ Không đóng Xcode trong lúc upload
- ✅ Kiểm tra email từ Apple nếu có lỗi

---

## BƯỚC 4: Setup App trong App Store Connect

### 4.1. Đăng nhập App Store Connect

1. Vào: https://appstoreconnect.apple.com
2. Đăng nhập bằng Apple Developer account

### 4.2. Tạo App mới (nếu chưa có)

1. Click **My Apps**
2. Click **+** (góc trên bên trái)
3. Chọn **New App**
4. Điền thông tin:
   - **Platform**: iOS
   - **Name**: Chat-Ai (hoặc tên bạn muốn)
   - **Primary Language**: Vietnamese hoặc English
   - **Bundle ID**: Chọn `com.whales.Chat-Ai` (phải match với Xcode)
   - **SKU**: `chat-ai-001` (hoặc bất kỳ mã nào, chỉ để tracking)
5. Click **Create**

### 4.3. Đợi Build xuất hiện

- Sau khi upload thành công, build sẽ xuất hiện trong **TestFlight** tab
- Có thể mất **10-30 phút** để Apple process build
- Build đầu tiên có thể cần **24-48 giờ** để review (Apple kiểm tra cơ bản)
- Các build sau thường được approve nhanh hơn (vài phút đến vài giờ)

---

## BƯỚC 5: Setup TestFlight

### 5.1. Vào TestFlight Tab

1. Trong App Store Connect, chọn app **Chat-Ai**
2. Click tab **TestFlight** ở trên cùng

### 5.2. Thêm Internal Testers (Tối đa 100 người)

1. Click **Internal Testing** ở sidebar trái
2. Click **+** để thêm tester
3. Nhập **Email Apple ID** của tester
4. Click **Add**
5. Tester sẽ nhận email mời

**Lưu ý**: Internal testers phải là thành viên trong team Apple Developer của bạn.

### 5.3. Thêm External Testers (Tối đa 10,000 người)

1. Click **External Testing** ở sidebar trái
2. Click **+** để tạo group mới (ví dụ: "Beta Testers")
3. Click vào group vừa tạo
4. Click **Add Builds to Test**
5. Chọn build bạn muốn test
6. Click **Next**
7. Điền thông tin:
   - **What to Test**: Mô tả ngắn gọn những gì tester cần test
   - **Feedback Email**: Email để nhận feedback
8. Click **Next**
9. Thêm tester:
   - Click **Add Testers**
   - Nhập email Apple ID của tester
   - Click **Add**
10. Click **Start Testing**
11. Build sẽ cần review (có thể mất 24-48h cho lần đầu)

---

## BƯỚC 6: Hướng dẫn Tester cài App

### 6.1. Tester nhận email mời

- Email từ Apple với subject: "You've been invited to test [App Name]"
- Click link trong email hoặc mở TestFlight app

### 6.2. Tester cài TestFlight App

- Tải **TestFlight** từ App Store (nếu chưa có)
- Mở TestFlight app

### 6.3. Accept invitation

- Mở email mời và click **Start Testing**
- Hoặc mở TestFlight app, app sẽ tự động xuất hiện

### 6.4. Cài App

- Trong TestFlight, tìm app **Chat-Ai**
- Click **Install**
- App sẽ được cài như app bình thường

---

## BƯỚC 7: Upload Build mới (Khi có update)

### 7.1. Tăng Build Number

1. Trong Xcode: **Project > Target > General**
2. Tăng **Build** number (ví dụ: từ 1 → 2)
3. **Version** có thể giữ nguyên hoặc tăng (ví dụ: 1.0 → 1.1)

### 7.2. Archive và Upload lại

- Làm lại **Bước 3**
- Build mới sẽ xuất hiện trong TestFlight sau vài phút
- Tester sẽ nhận thông báo có build mới

---

## ⚠️ Lưu ý quan trọng

### Build Expiration

- Build beta hết hạn sau **90 ngày**
- Cần upload build mới trước khi hết hạn
- Tester sẽ không thể mở app nếu build hết hạn

### Review Process

- **Build đầu tiên**: Có thể mất 24-48h để review
- **Build sau**: Thường nhanh hơn (vài phút đến vài giờ)
- Apple sẽ kiểm tra cơ bản: không có crash, không vi phạm guideline

### Certificates & Profiles

- Xcode sẽ tự động quản lý nếu bạn chọn **Automatically manage signing**
- Đảm bảo Apple Developer account có đủ quyền

### Testing Limits

- **Internal Testing**: Tối đa 100 người (không cần review)
- **External Testing**: Tối đa 10,000 người (cần review)

---

## 🐛 Troubleshooting

### Build không xuất hiện trong TestFlight

- Đợi 10-30 phút để Apple process
- Kiểm tra email từ Apple về lỗi (nếu có)
- Kiểm tra lại Bundle ID có match không

### Tester không nhận email mời

- Kiểm tra spam folder
- Đảm bảo email là Apple ID hợp lệ
- Tester có thể vào TestFlight app trực tiếp

### Build bị reject

- Xem email từ Apple để biết lý do
- Sửa lỗi và upload lại
- Thường là do: crash, vi phạm guideline, thiếu thông tin

---

## 📞 Hỗ trợ

- App Store Connect Help: https://help.apple.com/app-store-connect/
- TestFlight Documentation: https://developer.apple.com/testflight/
