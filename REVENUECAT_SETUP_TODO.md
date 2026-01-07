# 📋 RevenueCat Setup - TODO List

## ✅ Đã hoàn thành hôm nay:

- [x] Setup App Store Connect
  - [x] Tạo app "Free Chat For Every One"
  - [x] Bundle ID: `com.whales.Chat-Ai`
  - [x] Tạo Subscription Group: "Premium Subscriptions"
  - [x] Tạo 2 products: Weekly ($2.99/week), Monthly ($9.99/month)
  - [x] Set giá cho cả 2 gói

- [x] Setup RevenueCat
  - [x] Tạo account RevenueCat
  - [x] Tạo project "Chat AI"
  - [x] Lấy API key: `test_uChjxbHYKQFelVKOTKYMkUoHmry`

- [x] Code Swift
  - [x] Thêm RevenueCat SDK
  - [x] Tạo SubscriptionPlan model
  - [x] Tạo RevenueCatService
  - [x] Tạo PaywallView (UI đẹp)
  - [x] Config API key trong AppConfig.swift
  - [x] Thêm nút "Premium" vào ConversationListView

---

## 🔑 BƯỚC TIẾP THEO - Sau khi có P8 Key

### **BƯỚC 1: Lấy thông tin từ P8 Key** (5 phút)

Sau khi Admin tạo P8 key, bạn sẽ nhận được:
1. **File .p8** - Tải về và lưu an toàn
2. **Key ID** - Chuỗi 10 ký tự (ví dụ: ABC123DEFG)
3. **Issuer ID** - UUID dài (ví dụ: 57246542-96fe-1a63-e053-0824d0110)

📍 **Lấy Issuer ID tại**: https://appstoreconnect.apple.com/access/integrations/api
   - Ở đầu trang sẽ có "Issuer ID"
   - Click "Copy" để copy

---

### **BƯỚC 2: Upload P8 Key vào RevenueCat** (5 phút)

1. **Vào RevenueCat Dashboard**: https://app.revenuecat.com
2. **Click project "Chat AI"**
3. **Sidebar** → Click **"Project settings"** (icon bánh răng)
4. **Tab "Apps"** → Click **"Apple App Store"** hoặc **"Add app"**
5. **Điền thông tin**:
   - **App name**: `Free Chat For Every One`
   - **Bundle ID**: `com.whales.Chat-Ai`
   - **Upload file .p8**: Click "Choose file" → Upload file P8
   - **Key ID**: Paste Key ID (10 ký tự)
   - **Issuer ID**: Paste Issuer ID (UUID)
6. **Click "Save"**

✅ **Kết quả**: RevenueCat đã kết nối với App Store Connect!

---

### **BƯỚC 3: Tạo Entitlement** (2 phút)

**Entitlement** = Quyền truy cập (ví dụ: "premium" access)

1. **Sidebar** → Click **"Entitlements"**
2. **Click nút "+"** (Create new entitlement)
3. **Identifier**: Gõ `premium`
4. **Description**: Gõ `Premium access to all features`
5. **Click "Create"**

✅ **Kết quả**: Có entitlement "premium" rồi!

---

### **BƯỚC 4: Tạo Offering** (5 phút)

**Offering** = Nhóm các gói subscription để hiển thị cho user

1. **Sidebar** → Click **"Offerings"**
2. **Click nút "+"** (Create new offering)
3. **Identifier**: Gõ `default` (QUAN TRỌNG - code đang dùng "default")
4. **Description**: Gõ `Default subscription offering`
5. **Make this the current offering**: ✅ Tick checkbox
6. **Click "Create"**

✅ **Kết quả**: Có offering "default" rồi!

---

### **BƯỚC 5: Add Products vào Offering** (5 phút)

1. **Vẫn ở trang Offerings** → Click vào **"default"** offering vừa tạo
2. **Section "Packages"** → Click **"Add package"**

#### **Package 1: Weekly**
- **Identifier**: `weekly` (QUAN TRỌNG - code đang dùng)
- **Package type**: Chọn **"Weekly"**
- **Product**: Chọn **"com.whales.freechat.weekly"** (từ App Store)
- **Attach to entitlement**: Chọn **"premium"**
- **Click "Add"**

#### **Package 2: Monthly**
- **Click "Add package"** lần nữa
- **Identifier**: `monthly` (QUAN TRỌNG - code đang dùng)
- **Package type**: Chọn **"Monthly"**
- **Product**: Chọn **"com.whales.freechat.monthly"** (từ App Store)
- **Attach to entitlement**: Chọn **"premium"**
- **Click "Add"**

✅ **Kết quả**: Offering "default" có 2 packages (Weekly, Monthly)!

---

### **BƯỚC 6: Test trong app** (5 phút)

1. **Trong Xcode**: Build & Run (`⌘ + R`)
2. **Đăng nhập** với Google
3. **Bấm nút "Premium"** (icon crown màu vàng)
4. **Chọn gói** (Weekly hoặc Monthly)
5. **Bấm "Subscribe to ..."**
6. **Apple popup sẽ hiện ra** để xác nhận thanh toán (Face ID/Touch ID)
7. **QUAN TRỌNG**: Đăng nhập bằng **Sandbox Test Account** (không phải Apple ID thật!)

---

### **BƯỚC 7: Tạo Sandbox Test Account** (3 phút)

**Để test mua subscription mà KHÔNG mất tiền thật!**

1. **Vào App Store Connect**: https://appstoreconnect.apple.com
2. **Menu "Users and Access"**
3. **Tab "Sandbox"** (hoặc "Sandbox Testers")
4. **Click "+"** để tạo tester mới
5. **Điền thông tin**:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: Tạo email mới (ví dụ: `testuser123@gmail.com`)
   - **Password**: Tạo password mạnh
   - **Confirm Password**: Nhập lại
   - **Country/Region**: Vietnam
6. **Click "Add"**

✅ **Kết quả**: Có Sandbox Test Account rồi!

---

### **BƯỚC 8: Test mua subscription** (5 phút)

1. **Trên iPhone/Simulator**:
   - **Settings** → **App Store** → **Sandbox Account**
   - **Sign Out** (nếu đang đăng nhập)
   - **KHÔNG sign in ngay** (sẽ được hỏi khi mua)

2. **Trong app Chat AI**:
   - Bấm nút **"Premium"**
   - Chọn gói **Weekly** hoặc **Monthly**
   - Bấm **"Subscribe"**
   - Popup Apple sẽ hỏi đăng nhập
   - **Đăng nhập bằng Sandbox Test Account** vừa tạo
   - Xác nhận mua (Face ID/Touch ID)

3. **Kết quả**:
   - ✅ Mua thành công (KHÔNG mất tiền thật!)
   - ✅ App unlock tính năng premium
   - ✅ RevenueCat Dashboard hiển thị transaction

---

### **BƯỚC 9: Verify subscription hoạt động** (2 phút)

1. **Check trong code**:
   - App tự động check subscription status
   - User có entitlement "premium" → Unlock features

2. **Check trong RevenueCat Dashboard**:
   - **Sidebar** → **"Customers"**
   - Tìm user vừa mua
   - Xem subscription status

---

## 🐛 Troubleshooting

### **Lỗi: "No products found"**
- ✅ Check products đã được add vào offering chưa
- ✅ Check Bundle ID khớp nhau giữa Xcode, App Store Connect, RevenueCat
- ✅ Đợi 5-10 phút để Apple sync products

### **Lỗi: "Purchase failed"**
- ✅ Check đã đăng nhập Sandbox Account chưa
- ✅ Check P8 key đã upload đúng chưa
- ✅ Check Issuer ID và Key ID đúng chưa

### **Lỗi: "Invalid credentials"**
- ✅ Tạo lại P8 key
- ✅ Upload lại vào RevenueCat

---

## 📊 Kiểm tra cuối cùng

### **Checklist hoàn chỉnh:**

- [ ] P8 key đã upload vào RevenueCat
- [ ] Entitlement "premium" đã tạo
- [ ] Offering "default" đã tạo và set làm "current"
- [ ] 2 packages (weekly, monthly) đã add vào offering
- [ ] Sandbox Test Account đã tạo
- [ ] Test mua subscription thành công
- [ ] RevenueCat Dashboard hiển thị transaction
- [ ] App unlock tính năng premium

---

## 🎉 Sau khi hoàn thành

### **App đã sẵn sàng:**
- ✅ User có thể mua subscription qua App Store
- ✅ RevenueCat quản lý subscription tự động
- ✅ App unlock tính năng premium khi có subscription
- ✅ Analytics hiển thị trên RevenueCat Dashboard

### **Production checklist:**
- [ ] Thay Test API key bằng Live API key
- [ ] Test với Apple ID thật (sẽ mất tiền thật!)
- [ ] Submit app lên App Store để review
- [ ] Đợi Apple approve

---

## 📚 Tài liệu tham khảo

- **RevenueCat Docs**: https://docs.revenuecat.com/docs/getting-started
- **Apple In-App Purchase**: https://developer.apple.com/in-app-purchase/
- **RevenueCat Swift SDK**: https://github.com/RevenueCat/purchases-ios

---

## 💡 Tips

1. **Test trên nhiều devices** để đảm bảo subscription sync đúng
2. **Test restore purchases** để đảm bảo user có thể khôi phục
3. **Monitor RevenueCat Dashboard** để xem analytics
4. **Setup webhook** để nhận notification khi có subscription events

---

## ⏰ Tổng thời gian ước tính: **35-40 phút**

- Bước 1-2: ~10 phút (Upload P8 key)
- Bước 3-5: ~12 phút (Setup entitlements & offerings)
- Bước 6-8: ~13 phút (Test mua subscription)
- Bước 9: ~2 phút (Verify)

---

**Chúc bạn thành công! 🚀**

Nếu gặp lỗi, hãy check phần Troubleshooting hoặc docs RevenueCat!

