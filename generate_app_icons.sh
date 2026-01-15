#!/bin/bash

# Script để generate các App Icon sizes từ Logo 1.png

SOURCE_ICON="Chat-Ai/Assets.xcassets/AppIcon.appiconset/Logo 1.png"
OUTPUT_DIR="Chat-Ai/Assets.xcassets/AppIcon.appiconset"

# Kiểm tra file source có tồn tại không
if [ ! -f "$SOURCE_ICON" ]; then
    echo "❌ Không tìm thấy file: $SOURCE_ICON"
    exit 1
fi

echo "🔄 Đang generate App Icons từ Logo 1.png..."

# Tạo các icon sizes cần thiết
sips -z 40 40 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-20.png" 2>/dev/null || sips -Z 40 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-20.png"
sips -z 58 58 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-29.png" 2>/dev/null || sips -Z 58 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-29.png"
sips -z 80 80 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-40.png" 2>/dev/null || sips -Z 80 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-40.png"
sips -z 120 120 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-120.png" 2>/dev/null || sips -Z 120 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-120.png"
sips -z 152 152 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-152.png" 2>/dev/null || sips -Z 152 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-152.png"
sips -z 167 167 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-167.png" 2>/dev/null || sips -Z 167 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-167.png"
sips -z 180 180 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-180.png" 2>/dev/null || sips -Z 180 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-180.png"
sips -z 76 76 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-76.png" 2>/dev/null || sips -Z 76 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-76.png"
sips -z 167 167 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-83.5.png" 2>/dev/null || sips -Z 167 "$SOURCE_ICON" --out "$OUTPUT_DIR/AppIcon-83.5.png"

# Copy Logo 1.png thành AppIcon-1024.png
cp "$SOURCE_ICON" "$OUTPUT_DIR/AppIcon-1024.png"

echo "✅ Đã generate xong các App Icons!"
echo "📋 Files đã tạo:"
ls -lh "$OUTPUT_DIR"/*.png
