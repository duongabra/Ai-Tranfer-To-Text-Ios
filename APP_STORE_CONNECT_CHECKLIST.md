# App Store Connect - Checklist Cần Update

## ✅ Đã Fix Trong Code (Không cần làm gì thêm)

- ✅ Terms of Service và Privacy Policy links - đã hoạt động
- ✅ Delete Account feature - đã thêm vào Settings
- ✅ Subscription terms trong PaywallView - đã hiển thị đầy đủ
- ✅ UISupportedInterfaceOrientations cho iPad - đã fix đầy đủ 4 orientations

---

## ⚠️ CẦN UPDATE TRONG APP STORE CONNECT

### 1. ⚠️ **App Name** (Guideline 2.3.7 & 2.3.8)

**Vấn đề:**
- App name có từ "Free" (không được phép)
- App name không khớp giữa Marketplace và Device

**Cách fix:**

**Option 1: Đổi App Name trong App Store Connect (Khuyến nghị)**
1. Vào App Store Connect → My Apps → Chọn app
2. Vào **"App Information"**
3. Tìm field **"Name"** (App Store name)
4. Đổi từ "Free Chat For Every One" thành tên không có "Free"
   - Ví dụ: "Chat For Everyone" hoặc "Chat AI" hoặc "VidSum"
5. Click **"Save"**

**Option 2: Đổi Display Name trong Xcode để khớp**
1. Mở Xcode → Project → Target → **General**
2. Tìm **"Display Name"**
3. Đổi thành tên giống với App Store name
4. Build lại và upload

**Lưu ý:** Nên chọn Option 1 vì đơn giản hơn và không cần rebuild.

---

### 2. ⚠️ **In-App Purchase Metadata** (Guideline 2.1)

**Vấn đề:**
- In-App Purchase metadata có placeholder content (Name và Description)

**Cách fix:**

1. Vào App Store Connect → My Apps → Chọn app
2. Vào **"Features"** → **"In-App Purchases"**
3. Click vào từng subscription product (Weekly và Monthly)
4. Click **"Edit In-App Purchase Details"**
5. Điền đầy đủ thông tin:

   **Cho Weekly Subscription:**
   - **Reference Name**: `Weekly Pro` (hoặc tên bạn muốn)
   - **Name**: `Weekly Pro` (hoặc `Pro Weekly`)
   - **Description**: 
     ```
     Get unlimited access to all Pro features for one week. 
     Includes unlimited video analysis, AI-powered summaries, 
     and access to your knowledge library.
     ```
   - **Review Information**: 
     - Screenshot: Upload screenshot của PaywallView
     - Notes: "Weekly subscription plan for Pro features"

   **Cho Monthly Subscription:**
   - **Reference Name**: `Monthly Pro` (hoặc tên bạn muốn)
   - **Name**: `Monthly Pro` (hoặc `Pro Monthly`)
   - **Description**: 
     ```
     Get unlimited access to all Pro features for one month. 
     Best value! Includes unlimited video analysis, AI-powered summaries, 
     and access to your knowledge library.
     ```
   - **Review Information**: 
     - Screenshot: Upload screenshot của PaywallView
     - Notes: "Monthly subscription plan for Pro features - Best value option"

6. Click **"Save"** cho từng product
7. Sau khi sửa xong tất cả, quay lại **"App Version Information"** page
8. Click **"Submit for Review"** button ở trên cùng

**Lưu ý:** 
- Phải điền đầy đủ Name và Description, không được để placeholder
- Description nên mô tả rõ ràng về tính năng và giá trị của subscription

---

### 3. ⚠️ **Promotional Image** (Guideline 2.3.2)

**Vấn đề:**
- Promotional image giống với app icon

**Cách fix:**

**Option 1: Xóa Promotional Image (Nếu không muốn promote)**
1. Vào App Store Connect → My Apps → Chọn app
2. Vào **"Features"** → **"In-App Purchases"**
3. Click vào subscription product
4. Scroll xuống phần **"Promotional Image"**
5. Click **"Delete"** hoặc **"Remove"**
6. Click **"Save"**

**Option 2: Thay đổi Promotional Image (Nếu muốn promote)**
1. Tạo promotional image mới (1024x1024 hoặc 2048x2048)
2. Image phải khác với app icon và thể hiện rõ subscription offer
3. Upload image mới vào phần **"Promotional Image"**
4. Click **"Save"**

**Khuyến nghị:** Chọn Option 1 nếu không có kế hoạch promote subscription ngay.

---

### 4. ⚠️ **Support URL** (Guideline 1.5)

**Vấn đề:**
- Support URL không có thông tin support

**Cách fix:**

**Bước 1: Tạo trang Support**
1. Tạo trang support trên website của bạn: `https://quick-vid-read.lovable.app/support`
2. Trang này cần có:
   - Thông tin liên hệ (email support)
   - FAQ (Frequently Asked Questions)
   - Hướng dẫn sử dụng app
   - Cách report bugs
   - Thông tin về subscription và billing

**Bước 2: Update Support URL trong App Store Connect**
1. Vào App Store Connect → My Apps → Chọn app
2. Vào **"App Information"**
3. Tìm field **"Support URL"**
4. Cập nhật thành: `https://quick-vid-read.lovable.app/support`
5. Click **"Save"**

**Lưu ý:** 
- Support URL phải là trang web thực sự có thông tin support
- Không được là trang trống hoặc redirect
- Nên có email support hoặc form liên hệ

---

### 5. ⚠️ **Privacy Policy URL** (Guideline 3.1.2)

**Kiểm tra:**
1. Vào App Store Connect → My Apps → Chọn app
2. Vào **"App Privacy"** hoặc **"App Information"**
3. Kiểm tra **"Privacy Policy URL"** field
4. Đảm bảo URL là: `https://quick-vid-read.lovable.app/privacy`
5. Đảm bảo link hoạt động và có nội dung Privacy Policy đầy đủ

---

### 6. ⚠️ **Terms of Use (EULA) URL** (Guideline 3.1.2)

**Kiểm tra:**
1. Vào App Store Connect → My Apps → Chọn app
2. Vào **"App Information"**
3. Kiểm tra **"EULA"** hoặc **"Terms of Use"** field
4. Nếu có field này, đảm bảo URL là: `https://quick-vid-read.lovable.app/terms`
5. Hoặc có thể để trong **"App Description"** với link đến Terms

---

### 7. ⚠️ **Paid Apps Agreement** (Guideline 2.1)

**Kiểm tra:**
1. Vào App Store Connect
2. Vào **"Agreements, Tax, and Banking"**
3. Kiểm tra xem **"Paid Apps Agreement"** đã được accept chưa
4. Nếu chưa, click vào và accept agreement
5. Điền đầy đủ thông tin banking và tax nếu cần

**Lưu ý:** Cần có Paid Apps Agreement để in-app purchases hoạt động trong review.

---

## 📝 Checklist Trước Khi Resubmit

Sau khi fix tất cả các vấn đề trên:

- [ ] ✅ App Name đã được đổi (xóa "Free" hoặc đồng bộ với Display Name)
- [ ] ✅ In-App Purchase metadata đã được điền đầy đủ (Name, Description)
- [ ] ✅ Promotional Image đã được xóa hoặc thay đổi
- [ ] ✅ Support URL đã được tạo và cập nhật với nội dung support
- [ ] ✅ Privacy Policy URL đã được verify là hoạt động
- [ ] ✅ Terms of Use URL đã được verify là hoạt động
- [ ] ✅ Paid Apps Agreement đã được accept
- [ ] ✅ Build mới đã được upload với fixes về orientations
- [ ] ✅ App version information đã được cập nhật
- [ ] ✅ Đã test app trên iPad để đảm bảo không có bugs

---

## 🚀 Sau Khi Hoàn Thành

1. **Build và Upload:**
   - Build app mới với tất cả code fixes
   - Upload build mới lên App Store Connect

2. **Submit for Review:**
   - Vào **"App Version Information"**
   - Click **"Submit for Review"**

3. **Reply to Apple (Optional nhưng khuyến nghị):**
   - Vào **"App Review Information"**
   - Reply với message giải thích các fixes đã thực hiện:
   ```
   Dear Apple Review Team,
   
   We have addressed all the issues mentioned in the review:
   
   1. Fixed app name to remove "Free" reference
   2. Updated In-App Purchase metadata with complete Name and Description
   3. Removed/changed promotional images
   4. Created and updated Support URL with support information
   5. Fixed UISupportedInterfaceOrientations for iPad multitasking support
   6. Added Delete Account feature in Settings
   7. Added subscription terms and privacy links in PaywallView
   
   Please review the updated submission.
   
   Thank you!
   ```

---

## 📞 Nếu Cần Hỗ Trợ

- Apple Developer Support: https://developer.apple.com/contact/
- App Store Connect Help: https://help.apple.com/app-store-connect/
