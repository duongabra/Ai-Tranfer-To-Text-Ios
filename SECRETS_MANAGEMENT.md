# 🔐 Quản lý API Keys & Secrets trong iOS

## 📊 So sánh các phương pháp

| Phương pháp | An toàn | Dễ dùng | Khi nào dùng |
|-------------|---------|---------|--------------|
| **Hardcode trong code** | ❌ | ✅✅✅ | Học tập, prototype |
| **`.xcconfig` file** | ⚠️ | ✅✅ | Development, staging |
| **`.plist` file** | ⚠️ | ✅✅ | Development, staging |
| **Keychain** | ✅✅✅ | ⚠️ | Production |
| **Backend API** | ✅✅✅ | ⚠️ | Production (tốt nhất) |

---

## 1️⃣ Hardcode (Hiện tại - Đơn giản nhất)

### AppConfig.swift
```swift
struct AppConfig {
    static let aiAPIKey = "gsk_xxx"  // ← Hardcode
}
```

**Ưu điểm:**
- ✅ Cực kỳ đơn giản
- ✅ Không cần setup gì thêm

**Nhược điểm:**
- ❌ Lộ key khi commit Git
- ❌ Không an toàn
- ❌ Khó quản lý nhiều môi trường

**Khi nào dùng:**
- Học tập, làm quen
- Prototype nhanh
- API key public (không quan trọng)

---

## 2️⃣ .xcconfig File (Giống .env trong Web)

### Bước 1: Tạo file `Config.xcconfig`

```
// Config.xcconfig
SUPABASE_URL = https:/$()/your-project.supabase.co
AI_API_KEY = gsk_xxx
```

### Bước 2: Add vào Xcode

1. Mở Xcode
2. Project Navigator → Click project root
3. Select project (màu xanh)
4. Tab "Info" → Configurations
5. Debug/Release → Set configuration file: `Config.xcconfig`

### Bước 3: Đọc trong code

```swift
// Environment.swift
enum Environment {
    static var aiAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AI_API_KEY") as? String else {
            fatalError("Missing AI_API_KEY")
        }
        return key
    }
}

// Usage
let key = Environment.aiAPIKey
```

### Bước 4: Add vào .gitignore

```
Config.xcconfig
```

**Ưu điểm:**
- ✅ Không commit lên Git
- ✅ Dễ quản lý nhiều môi trường (Dev.xcconfig, Prod.xcconfig)
- ✅ Chuẩn iOS

**Nhược điểm:**
- ⚠️ Vẫn có thể bị reverse engineer từ .app file
- ⚠️ Cần setup trong Xcode

---

## 3️⃣ .plist File

### Bước 1: Tạo `Secrets.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AI_API_KEY</key>
    <string>gsk_xxx</string>
</dict>
</plist>
```

### Bước 2: Đọc trong code

```swift
// SecretsManager.swift
enum SecretsManager {
    private static var secrets: [String: Any]? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let xml = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
    
    static var aiAPIKey: String {
        return secrets?["AI_API_KEY"] as? String ?? ""
    }
}

// Usage
let key = SecretsManager.aiAPIKey
```

### Bước 3: Add vào .gitignore

```
Secrets.plist
```

### Bước 4: Tạo example file

```
Secrets.plist.example  ← Commit file này
Secrets.plist          ← KHÔNG commit
```

**Ưu điểm:**
- ✅ Dễ dùng
- ✅ Không commit lên Git
- ✅ Dễ share với team (dùng .example)

**Nhược điểm:**
- ⚠️ Vẫn có thể bị reverse engineer
- ⚠️ Cần nhớ copy từ .example

---

## 4️⃣ Keychain (An toàn nhất - Local)

### Code

```swift
// KeychainManager.swift
enum KeychainManager {
    static func save(key: String, value: String) -> Bool {
        // ... code ở file KeychainManager.swift
    }
    
    static func get(key: String) -> String? {
        // ... code ở file KeychainManager.swift
    }
}

// Usage
// Lần đầu: Save key vào Keychain (có thể qua Settings screen)
KeychainManager.save(key: "AI_API_KEY", value: "gsk_xxx")

// Sau đó: Get key từ Keychain
if let apiKey = KeychainManager.get(key: "AI_API_KEY") {
    // Use apiKey
}
```

**Ưu điểm:**
- ✅✅✅ Rất an toàn (encrypted)
- ✅ Không bị reverse engineer dễ dàng
- ✅ Persist giữa các lần mở app

**Nhược điểm:**
- ⚠️ Phức tạp hơn
- ⚠️ Cần UI để user nhập key lần đầu
- ⚠️ Vẫn có thể bị jailbroken device đọc được

---

## 5️⃣ Backend Proxy (Tốt nhất cho Production)

### Architecture

```
iOS App → Your Backend → AI API
         (có API key)
```

### Backend (Node.js example)

```javascript
// server.js
app.post('/api/chat', async (req, res) => {
  const { message } = req.body;
  
  // API key nằm ở backend, không lộ ra client
  const response = await fetch('https://api.groq.com/...', {
    headers: {
      'Authorization': `Bearer ${process.env.GROQ_API_KEY}`
    },
    body: JSON.stringify({ message })
  });
  
  res.json(await response.json());
});
```

### iOS App

```swift
// Chỉ gọi backend, không cần API key
func sendMessage(_ text: String) async throws -> String {
    let url = URL(string: "https://your-backend.com/api/chat")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["message": text]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    // Parse response...
}
```

**Ưu điểm:**
- ✅✅✅ An toàn tuyệt đối
- ✅ API key không bao giờ lộ ra client
- ✅ Có thể monitor, rate limit, analytics
- ✅ Có thể thay đổi API key mà không cần update app

**Nhược điểm:**
- ⚠️ Cần maintain backend
- ⚠️ Tốn chi phí hosting
- ⚠️ Phức tạp hơn nhiều

---

## 🎯 Khuyến nghị theo từng giai đoạn

### Giai đoạn 1: Học tập (Hiện tại của bạn)
```swift
// AppConfig.swift - Hardcode
static let aiAPIKey = "gsk_xxx"
```
→ **OK cho học tập!** Đơn giản, tập trung học Swift

### Giai đoạn 2: Development
```
Config.xcconfig + .gitignore
```
→ Không commit key lên Git

### Giai đoạn 3: Beta Testing
```
Keychain + Settings screen
```
→ User tự nhập API key

### Giai đoạn 4: Production
```
Backend Proxy
```
→ An toàn tuyệt đối

---

## 📝 Setup cho project này (Nếu muốn làm đúng)

### Option A: Dùng .plist (Dễ nhất)

1. **Tạo `Secrets.plist`** (đã có template: `Secrets.plist.example`)
2. **Copy và điền thông tin:**
   ```bash
   cp Chat-Ai/Config/Secrets.plist.example Chat-Ai/Config/Secrets.plist
   # Mở Secrets.plist và điền API keys
   ```
3. **Update AppConfig.swift:**
   ```swift
   struct AppConfig {
       static let aiAPIKey = SecretsManager.aiAPIKey
       static let supabaseURL = SecretsManager.supabaseURL
       // ...
   }
   ```
4. **Đảm bảo .gitignore:**
   ```
   Secrets.plist
   ```

### Option B: Dùng Keychain (An toàn nhất)

1. **Tạo Settings screen** để user nhập API key
2. **Save vào Keychain** lần đầu
3. **Get từ Keychain** mỗi lần dùng
4. **Không commit key** vào Git

---

## 🔍 So sánh với Web Development

| iOS | Web (Node.js) |
|-----|---------------|
| Hardcode trong code | Hardcode trong code |
| `.xcconfig` | `.env` |
| `.plist` | `.env` |
| Keychain | Environment variables |
| Backend proxy | Backend proxy |

**Điểm khác:**
- iOS: App được compile → khó thay đổi config sau khi deploy
- Web: Server-side → dễ thay đổi env vars

---

## ⚠️ Lưu ý quan trọng

1. **KHÔNG BAO GIỜ commit API keys lên Git**
2. **Luôn dùng .gitignore** cho config files
3. **Trong production, dùng backend proxy** nếu có thể
4. **API keys trong app có thể bị reverse engineer** (dù có obfuscate)
5. **Keychain an toàn nhất cho local storage**, nhưng vẫn có thể bị hack trên jailbroken device

---

## 📚 Tài liệu tham khảo

- [Apple Keychain Documentation](https://developer.apple.com/documentation/security/keychain_services)
- [Xcode Configuration Files](https://nshipster.com/xcconfig/)
- [iOS Security Best Practices](https://developer.apple.com/documentation/security)

---

**Kết luận:** Cho project học tập, hardcode OK. Cho production, dùng backend proxy! 🚀

