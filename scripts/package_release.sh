#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Codex Peek"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICON_FILE="$DIST_DIR/AppIcon.icns"
STAGING_DIR="$DIST_DIR/dmg-staging"
RELEASE_DIR="$DIST_DIR/releases"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"

cd "$ROOT_DIR"

echo "构建 release 二进制..."
swift build -c release

echo "生成 App 图标..."
rm -rf "$ICONSET_DIR" "$ICON_FILE"
mkdir -p "$DIST_DIR"
swift Tools/CreateAppIcon.swift "$ICONSET_DIR" "Assets/AppIconSource.png"
sips -s format icns "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICON_FILE" >/dev/null

echo "组装 App bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "CodexPeek/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
install -m 755 ".build/release/CodexPeek" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 自动注入构建号：使用 git 提交总数作为 CFBundleVersion
BUILD_NUMBER=$(git rev-list --count HEAD)
echo "自动构建号: $BUILD_NUMBER"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

echo "本地签名 App..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "准备 DMG 内容..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$RELEASE_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
cat > "$STAGING_DIR/安装说明.txt" <<'EOF'
Codex Peek 安装说明

1. 将「Codex Peek.app」拖到「Applications」文件夹。
2. 安装完成后，从「应用程序」里打开 Codex Peek。
3. Codex Peek 是菜单栏应用，启动后只会显示在屏幕顶部菜单栏，不会显示在 Dock 栏。
4. 如果 macOS 提示无法验证开发者，请在「系统设置」->「隐私与安全性」中允许打开，或右键点击应用后选择「打开」。

使用前请先确认你已经登录 Codex CLI，否则应用会提示需要登录后才能读取真实用量。
EOF

echo "生成 DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"

echo "发布包已生成：$DMG_PATH"
