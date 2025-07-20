#!/bin/bash

# Open Anki 应用图标设置脚本
# 一键生成图标并替换到所有平台

echo "🚀 设置 Open Anki 应用图标..."

# 检查 ImageMagick
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo "❌ 请先安装 ImageMagick: brew install imagemagick"
    exit 1
fi

# 确定使用哪个命令
if command -v magick &> /dev/null; then
    IMG_CMD="magick"
else
    IMG_CMD="convert"
fi

# 创建图标目录
rm -rf assets/icons
mkdir -p assets/icons

# 生成各种尺寸的图标
echo "📱 生成图标..."
sizes=(16 29 32 40 48 60 64 72 76 80 87 96 120 128 144 152 167 180 192 384 512 1024)
for size in "${sizes[@]}"; do
    $IMG_CMD assets/icon.svg -resize ${size}x${size} assets/icons/icon_${size}.png
done

# 替换 iOS 图标
echo "🍎 替换 iOS 图标..."
ios_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
cp assets/icons/icon_1024.png "$ios_dir/Icon-App-1024x1024@1x.png"
cp assets/icons/icon_180.png "$ios_dir/Icon-App-60x60@3x.png"
cp assets/icons/icon_120.png "$ios_dir/Icon-App-60x60@2x.png"
cp assets/icons/icon_87.png "$ios_dir/Icon-App-29x29@3x.png"
cp assets/icons/icon_80.png "$ios_dir/Icon-App-40x40@2x.png"
cp assets/icons/icon_76.png "$ios_dir/Icon-App-76x76@1x.png"
cp assets/icons/icon_60.png "$ios_dir/Icon-App-60x60@1x.png"
cp assets/icons/icon_40.png "$ios_dir/Icon-App-20x20@2x.png"
cp assets/icons/icon_29.png "$ios_dir/Icon-App-29x29@1x.png"

# 替换 Android 图标
echo "🤖 替换 Android 图标..."
cp assets/icons/icon_72.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png
cp assets/icons/icon_48.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png
cp assets/icons/icon_96.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
cp assets/icons/icon_144.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
cp assets/icons/icon_192.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# 替换 Web 图标
echo "🌐 替换 Web 图标..."
cp assets/icons/icon_512.png web/icons/Icon-512.png
cp assets/icons/icon_192.png web/icons/Icon-192.png
cp assets/icons/icon_16.png web/favicon.png

echo "✅ 图标设置完成！"
echo "💡 运行 'flutter clean && flutter pub get' 应用更改" 