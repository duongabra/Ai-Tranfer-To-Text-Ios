# Hướng dẫn Fix App Icon cho TestFlight

## 🔴 Lỗi hiện tại:
- Thiếu icon 120x120 cho iPhone
- Thiếu icon 152x152 cho iPad  
- Thiếu CFBundleIconName trong Info.plist

## ✅ Đã fix:
1. ✅ Đã thêm `CFBundleIconName = AppIcon` vào Info.plist
2. ✅ Đã cập nhật Contents.json với đầy đủ icon sizes

## 📋 Bước tiếp theo: Tạo các file icon

### Cách 1: Dùng Logo.png hiện có (Nhanh nhất)

1. **Mở Logo.png trong Preview hoặc Photoshop**
   - File location: `Chat-Ai/Assets.xcassets/Home/Logo.imageset/Logo.png`

2. **Tạo các icon sizes cần thiết:**
   - 1024x1024 (AppIcon-1024.png) - Bắt buộc
   - 120x120 (AppIcon-120.png) - Bắt buộc cho iPhone
   - 152x152 (AppIcon-152.png) - Bắt buộc cho iPad
   - 180x180 (AppIcon-180.png) - Cho iPhone
   - 167x167 (AppIcon-167.png) - Cho iPad Pro
   - 76x76 (AppIcon-76.png) - Cho iPad
   - 83.5x83.5 (AppIcon-83.5.png) - Cho iPad Pro
   - 60x60, 40x40, 29x29, 20x20 (các sizes nhỏ hơn)

3. **Lưu các file vào:**
   ```
   Chat-Ai/Assets.xcassets/AppIcon.appiconset/
   ```

### Cách 2: Dùng công cụ online (Dễ nhất)

1. **Vào website:** https://www.appicon.co/ hoặc https://appicon.build/
2. **Upload Logo.png** (1024x1024 hoặc lớn hơn)
3. **Chọn iOS platform**
4. **Download** và giải nén
5. **Copy tất cả files** vào `Chat-Ai/Assets.xcassets/AppIcon.appiconset/`

### Cách 3: Dùng Xcode (Khuyến nghị)

1. **Mở Xcode**
2. **Vào:** `Chat-Ai/Assets.xcassets/AppIcon.appiconset/`
3. **Click vào AppIcon** trong Xcode
4. **Kéo thả icon 1024x1024** vào slot "App Store" (1024x1024)
5. **Xcode sẽ tự động generate** các sizes khác từ icon 1024x1024

## 🎯 Icon sizes tối thiểu cần có:

| Size | Filename | Platform | Required |
|------|----------|----------|----------|
| 1024x1024 | AppIcon-1024.png | Universal | ✅ Bắt buộc |
| 120x120 | AppIcon-120.png | iPhone | ✅ Bắt buộc |
| 152x152 | AppIcon-152.png | iPad | ✅ Bắt buộc |
| 180x180 | AppIcon-180.png | iPhone | Khuyến nghị |
| 167x167 | AppIcon-167.png | iPad Pro | Khuyến nghị |

## ⚡ Quick Fix (Nếu có icon 1024x1024):

1. **Tạo icon 1024x1024** từ Logo.png
2. **Đặt tên:** `AppIcon-1024.png`
3. **Copy vào:** `Chat-Ai/Assets.xcassets/AppIcon.appiconset/`
4. **Mở Xcode** → Vào AppIcon → Kéo thả vào slot 1024x1024
5. **Xcode sẽ tự động tạo** các sizes còn lại

## 🔄 Sau khi thêm icon:

1. **Clean Build Folder:** `Cmd + Shift + K`
2. **Archive lại:** `Product > Archive`
3. **Validate lại** để kiểm tra

## 📝 Lưu ý:

- Icon phải là **PNG format**
- Icon phải **không có alpha channel** (không trong suốt)
- Icon nên là **square** (vuông)
- Icon nên có **rounded corners** (Apple sẽ tự động làm tròn)
