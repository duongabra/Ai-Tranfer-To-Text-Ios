#!/bin/bash
# Script để build nhanh app từ terminal

echo "🔨 Building Chat-Ai..."

# Build app
xcodebuild -project Chat-Ai.xcodeproj \
  -scheme Chat-Ai \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

echo "✅ Build completed!"
echo "💡 Quay lại Xcode và nhấn ⌘+R để chạy app với code mới"

