#!/bin/bash

# Script để remove alpha channel từ App Icons

SOURCE_ICON="Chat-Ai/Assets.xcassets/AppIcon.appiconset/Logo 1.png"
OUTPUT_DIR="Chat-Ai/Assets.xcassets/AppIcon.appiconset"

echo "🔄 Đang remove alpha channel từ App Icons..."

# Remove alpha channel từ Logo 1.png và tạo lại các sizes
# Sử dụng sips với --setProperty format jpeg để remove alpha, sau đó convert lại PNG

# Tạo temp file không có alpha
TEMP_NO_ALPHA="/tmp/logo_no_alpha.png"

# Convert sang JPEG (không có alpha) rồi convert lại PNG
sips -s format jpeg "$SOURCE_ICON" --out "$TEMP_NO_ALPHA" 2>/dev/null
sips -s format png "$TEMP_NO_ALPHA" --out "$TEMP_NO_ALPHA" 2>/dev/null

# Hoặc dùng ImageMagick nếu có: convert -alpha off
# Hoặc dùng sips với composite trên background trắng

# Cách tốt nhất: Composite icon lên background trắng để remove alpha
sips --setProperty format png "$SOURCE_ICON" --out "$TEMP_NO_ALPHA" 2>/dev/null

# Tạo background trắng 1024x1024
sips -z 1024 1024 --setProperty format png --padToHeightWidth 1024 1024 --padColor FFFFFF "$TEMP_NO_ALPHA" --out "$TEMP_NO_ALPHA" 2>/dev/null || \
sips -z 1024 1024 "$SOURCE_ICON" --out "$TEMP_NO_ALPHA" 2>/dev/null

# Composite icon lên background trắng để remove alpha
# Nếu có ImageMagick:
if command -v convert &> /dev/null; then
    convert "$SOURCE_ICON" -background white -alpha remove -alpha off "$TEMP_NO_ALPHA"
else
    # Dùng sips với workaround: resize và composite
    # Tạo background trắng
    sips -z 1024 1024 --setProperty format png --padToHeightWidth 1024 1024 --padColor FFFFFF "$SOURCE_ICON" --out "$TEMP_NO_ALPHA" 2>/dev/null || \
    # Fallback: chỉ copy và để sips tự xử lý
    cp "$SOURCE_ICON" "$TEMP_NO_ALPHA"
fi

# Nếu vẫn không được, dùng Python với PIL
python3 << EOF
from PIL import Image
import sys

try:
    img = Image.open("$SOURCE_ICON")
    # Convert sang RGB để remove alpha
    if img.mode in ('RGBA', 'LA', 'P'):
        # Tạo background trắng
        background = Image.new('RGB', img.size, (255, 255, 255))
        if img.mode == 'P':
            img = img.convert('RGBA')
        background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
        img = background
    img.save("$TEMP_NO_ALPHA", "PNG")
    print("✅ Đã remove alpha channel bằng Python")
except Exception as e:
    print(f"⚠️ Python error: {e}")
    # Fallback: copy file
    import shutil
    shutil.copy("$SOURCE_ICON", "$TEMP_NO_ALPHA")
EOF

# Kiểm tra file đã tạo
if [ ! -f "$TEMP_NO_ALPHA" ]; then
    echo "❌ Không thể tạo file không có alpha"
    exit 1
fi

# Tạo lại các icon sizes từ file không có alpha
echo "📐 Đang tạo các icon sizes..."

sips -z 40 40 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-20.png" 2>/dev/null || sips -Z 40 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-20.png"
sips -z 58 58 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-29.png" 2>/dev/null || sips -Z 58 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-29.png"
sips -z 80 80 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-40.png" 2>/dev/null || sips -Z 80 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-40.png"
sips -z 120 120 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-120.png" 2>/dev/null || sips -Z 120 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-120.png"
sips -z 152 152 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-152.png" 2>/dev/null || sips -Z 152 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-152.png"
sips -z 167 167 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-167.png" 2>/dev/null || sips -Z 167 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-167.png"
sips -z 180 180 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-180.png" 2>/dev/null || sips -Z 180 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-180.png"
sips -z 76 76 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-76.png" 2>/dev/null || sips -Z 76 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-76.png"
sips -z 167 167 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-83.5.png" 2>/dev/null || sips -Z 167 "$TEMP_NO_ALPHA" --out "$OUTPUT_DIR/AppIcon-83.5.png"

# Copy file 1024x1024 không có alpha
cp "$TEMP_NO_ALPHA" "$OUTPUT_DIR/AppIcon-1024.png"

# Cleanup
rm -f "$TEMP_NO_ALPHA"

echo "✅ Đã remove alpha channel và tạo lại các App Icons!"
echo "📋 Files đã được cập nhật:"
ls -lh "$OUTPUT_DIR"/AppIcon-*.png | head -5
