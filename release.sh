#!/bin/bash
set -e

# 1. 删除 pubspec.yaml 中的 assets/anki*.apkg 行
sed -i.bak '/assets\/anki.*\.apkg/d' pubspec.yaml

echo "已从 pubspec.yaml 移除 assets/anki*.apkg 相关行。"

echo "开始打包 iOS 发布包..."
# 2. 打包 iOS 发布包
flutter build ios --release

echo "iOS 发布包已生成。" 