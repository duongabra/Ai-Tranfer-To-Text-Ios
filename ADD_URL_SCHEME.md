# Add URL Scheme cho OAuth Callback

## Cách 1: Trong Xcode (Dễ nhất)

1. **Mở Xcode**
2. Click **TARGETS → Chat-Ai** (không phải PROJECT)
3. Tab **Info**
4. Scroll xuống tìm **"URL Types"** hoặc add key mới
5. Click **"+"** để add URL Type mới
6. Điền:
   - **Identifier**: `com.whales.Chat-Ai.auth`
   - **URL Schemes**: `chatai`
   - **Role**: Editor

## Cách 2: Add trực tiếp vào Info.plist

Nếu bạn thấy key **"URL types"** trong Target Info:

1. Expand **"URL types"**
2. Click **"+"** để add item
3. Expand item vừa tạo
4. Add:
   - **Document Role**: Editor
   - **URL identifier**: com.whales.Chat-Ai.auth
   - **URL Schemes**: (Array)
     - Item 0: `chatai`

## Kết quả mong đợi:

Sau khi add, bạn sẽ thấy trong Target Info:

```
URL types (Array)
  └─ Item 0 (Dictionary)
      ├─ Document Role: Editor
      ├─ URL identifier: com.whales.Chat-Ai.auth
      └─ URL Schemes (Array)
          └─ Item 0: chatai
```

## Test:

Sau khi add xong:

1. Clean Build: ⌘ + Shift + K
2. Build: ⌘ + B
3. Run: ⌘ + R

Khi OAuth callback, URL `chatai://auth/callback#access_token=xxx` sẽ mở app của bạn!
