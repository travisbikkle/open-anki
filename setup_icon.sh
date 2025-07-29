#!/bin/bash

# Open Anki 应用图标设置脚本
# 一键生成图标并替换到所有平台

echo "🚀 设置 Open Anki 应用图标..."

# 检查 ImageMagick
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo "❌ 请先安装 ImageMagick: brew install imagemagick"
    exit 1
fi
if command -v magick &> /dev/null; then
    IMG_CMD="magick"
else
    IMG_CMD="convert"
fi

# 创建图标目录
rm -rf assets/icons
mkdir -p assets/icons

# 生成各种尺寸的图标（补全所有iOS需要的尺寸）
echo "📱 生成图标..."
sizes=(16 20 29 32 40 48 58 60 64 72 76 80 83.5 87 96 120 128 144 152 167 180 192 384 512 1024)
for size in "${sizes[@]}"; do
    # 83.5特殊处理为167x167
    if [[ "$size" == "83.5" ]]; then
        $IMG_CMD assets/icon.png -resize 167x167 assets/icons/icon_167.png
    else
        $IMG_CMD assets/icon.png -resize ${size}x${size} assets/icons/icon_${size}.png
    fi
    # 兼容整数命名
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        $IMG_CMD assets/icon.png -resize ${size}x${size} assets/icons/icon_${size}.png
    fi
    # 兼容小数命名
    if [[ "$size" =~ ^[0-9]+\.[0-9]+$ ]]; then
        intsize=$(echo $size | awk '{printf "%d", $1*2}')
        $IMG_CMD assets/icon.png -resize ${intsize}x${intsize} assets/icons/icon_${intsize}.png
    fi
    # 兼容@2x/@3x
    for mult in 2 3; do
        px=$(echo "$size * $mult" | bc | awk '{printf "%d", $1}')
        $IMG_CMD assets/icon.png -resize ${px}x${px} assets/icons/icon_${size}x${size}@${mult}x.png
    done
    # 83.5@2x特殊
    if [[ "$size" == "83.5" ]]; then
        $IMG_CMD assets/icon.png -resize 167x167 assets/icons/Icon-App-83.5x83.5@2x.png
    fi
    # 1024特殊
    if [[ "$size" == "1024" ]]; then
        $IMG_CMD assets/icon.png -resize 1024x1024 assets/icons/Icon-App-1024x1024@1x.png
    fi
    # 60@1x特殊
    if [[ "$size" == "60" ]]; then
        $IMG_CMD assets/icon.png -resize 60x60 assets/icons/Icon-App-60x60@1x.png
    fi
    # 60@2x
    if [[ "$size" == "60" ]]; then
        $IMG_CMD assets/icon.png -resize 120x120 assets/icons/Icon-App-60x60@2x.png
    fi
    # 60@3x
    if [[ "$size" == "60" ]]; then
        $IMG_CMD assets/icon.png -resize 180x180 assets/icons/Icon-App-60x60@3x.png
    fi
    # 29@1x
    if [[ "$size" == "29" ]]; then
        $IMG_CMD assets/icon.png -resize 29x29 assets/icons/Icon-App-29x29@1x.png
    fi
    # 29@2x
    if [[ "$size" == "29" ]]; then
        $IMG_CMD assets/icon.png -resize 58x58 assets/icons/Icon-App-29x29@2x.png
    fi
    # 29@3x
    if [[ "$size" == "29" ]]; then
        $IMG_CMD assets/icon.png -resize 87x87 assets/icons/Icon-App-29x29@3x.png
    fi
    # 40@1x
    if [[ "$size" == "40" ]]; then
        $IMG_CMD assets/icon.png -resize 40x40 assets/icons/Icon-App-40x40@1x.png
    fi
    # 40@2x
    if [[ "$size" == "40" ]]; then
        $IMG_CMD assets/icon.png -resize 80x80 assets/icons/Icon-App-40x40@2x.png
    fi
    # 40@3x
    if [[ "$size" == "40" ]]; then
        $IMG_CMD assets/icon.png -resize 120x120 assets/icons/Icon-App-40x40@3x.png
    fi
    # 76@1x
    if [[ "$size" == "76" ]]; then
        $IMG_CMD assets/icon.png -resize 76x76 assets/icons/Icon-App-76x76@1x.png
    fi
    # 76@2x
    if [[ "$size" == "76" ]]; then
        $IMG_CMD assets/icon.png -resize 152x152 assets/icons/Icon-App-76x76@2x.png
    fi
    # 20@1x
    if [[ "$size" == "20" ]]; then
        $IMG_CMD assets/icon.png -resize 20x20 assets/icons/Icon-App-20x20@1x.png
    fi
    # 20@2x
    if [[ "$size" == "20" ]]; then
        $IMG_CMD assets/icon.png -resize 40x40 assets/icons/Icon-App-20x20@2x.png
    fi
    # 20@3x
    if [[ "$size" == "20" ]]; then
        $IMG_CMD assets/icon.png -resize 60x60 assets/icons/Icon-App-20x20@3x.png
    fi
    # 83.5@2x
    if [[ "$size" == "83.5" ]]; then
        $IMG_CMD assets/icon.png -resize 167x167 assets/icons/Icon-App-83.5x83.5@2x.png
    fi
    # 167@1x
    if [[ "$size" == "167" ]]; then
        $IMG_CMD assets/icon.png -resize 167x167 assets/icons/Icon-App-83.5x83.5@2x.png
    fi
    # 152@1x
    if [[ "$size" == "152" ]]; then
        $IMG_CMD assets/icon.png -resize 152x152 assets/icons/Icon-App-76x76@2x.png
    fi
    # 180@1x
    if [[ "$size" == "180" ]]; then
        $IMG_CMD assets/icon.png -resize 180x180 assets/icons/Icon-App-60x60@3x.png
    fi
    # 120@1x
    if [[ "$size" == "120" ]]; then
        $IMG_CMD assets/icon.png -resize 120x120 assets/icons/Icon-App-60x60@2x.png
    fi
    # 87@1x
    if [[ "$size" == "87" ]]; then
        $IMG_CMD assets/icon.png -resize 87x87 assets/icons/Icon-App-29x29@3x.png
    fi
    # 58@1x
    if [[ "$size" == "58" ]]; then
        $IMG_CMD assets/icon.png -resize 58x58 assets/icons/Icon-App-29x29@2x.png
    fi
    # 167@1x
    if [[ "$size" == "167" ]]; then
        $IMG_CMD assets/icon.png -resize 167x167 assets/icons/Icon-App-83.5x83.5@2x.png
    fi
    # 1024@1x
    if [[ "$size" == "1024" ]]; then
        $IMG_CMD assets/icon.png -resize 1024x1024 assets/icons/Icon-App-1024x1024@1x.png
    fi

done

# 批量覆盖 iOS AppIcon.appiconset
ios_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
cp assets/icons/Icon-App-*.png "$ios_dir/" 2>/dev/null

# 删除未分配的icon文件
rm -f "$ios_dir/Icon-App-60@1x.png"

# 提示用户检查Contents.json
cat <<EOF

⚠️ 请用 appicon.co 生成并覆盖 Contents.json，确保所有icon都被正确分配，无警告！
⚠️ 用Xcode预览AppIcon.appiconset，确认所有slot都为主视觉，无黄色警告！

EOF

echo "✅ iOS icon 批量替换完成！"
echo "💡 运行 'flutter clean && flutter pub get' 应用更改"