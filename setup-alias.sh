#!/bin/bash
# Script để setup alias cho build nhanh

echo "📝 Thêm alias vào ~/.zshrc..."

# Thêm alias vào .zshrc
cat >> ~/.zshrc << 'EOF'

# Chat-Ai quick build alias
alias chatai-build="cd /Users/duong/Desktop/code/Chat-Ai && xcodebuild -project Chat-Ai.xcodeproj -scheme Chat-Ai -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build"

EOF

echo "✅ Đã thêm alias!"
echo ""
echo "🔄 Reload shell:"
echo "   source ~/.zshrc"
echo ""
echo "💡 Sau đó bạn có thể gõ 'chatai-build' ở bất kỳ đâu để build app"

