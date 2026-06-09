#!/bin/bash
# Stop script execution immediately if any command exits with a non-zero code
set -e

echo "============================================="
echo "   Building MouseControl macOS Application   "
echo "============================================="

APP_NAME="MouseControl.app"
MACOS_DIR="${APP_NAME}/Contents/MacOS"
RESOURCES_DIR="${APP_NAME}/Contents/Resources"

# 1. Clean previous builds and kill running app instances
echo "[1/6] Terminating running app instances and removing old bundle..."
killall MouseControl 2>/dev/null || true
if [ -d "${APP_NAME}" ]; then
    rm -rf "${APP_NAME}"
fi

# 2. Recreate directory structure
echo "[2/6] Constructing application structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. Compile high-resolution AppIcon if source exists
if [ -f "icon_source.png" ]; then
    echo "[3/6] Generating Apple AppIcon (.icns) from custom image..."
    ICONSET="AppIcon.iconset"
    mkdir -p "${ICONSET}"
    
    # Scale PNG to all standard macOS icon sizes natively using sips (built-in macOS tool)
    sips -s format png -z 16 16     icon_source.png --out "${ICONSET}/icon_16x16.png"
    sips -s format png -z 32 32     icon_source.png --out "${ICONSET}/icon_16x16@2x.png"
    sips -s format png -z 32 32     icon_source.png --out "${ICONSET}/icon_32x32.png"
    sips -s format png -z 64 64     icon_source.png --out "${ICONSET}/icon_32x32@2x.png"
    sips -s format png -z 128 128   icon_source.png --out "${ICONSET}/icon_128x128.png"
    sips -s format png -z 256 256   icon_source.png --out "${ICONSET}/icon_128x128@2x.png"
    sips -s format png -z 256 256   icon_source.png --out "${ICONSET}/icon_256x256.png"
    sips -s format png -z 512 512   icon_source.png --out "${ICONSET}/icon_256x256@2x.png"
    sips -s format png -z 512 512   icon_source.png --out "${ICONSET}/icon_512x512.png"
    sips -s format png -z 1024 1024 icon_source.png --out "${ICONSET}/icon_512x512@2x.png"
    
    # Compile into system-standard .icns file
    iconutil -c icns "${ICONSET}" -o "${RESOURCES_DIR}/AppIcon.icns"
    
    # Clean up temporary iconset folder
    rm -rf "${ICONSET}"
    echo "      Custom gaming mouse icon compiled and integrated successfully."
else
    echo "[3/6] Warning: icon_source.png not found. Skipping icon generation."
fi

# 4. Locate system macOS SDK path
echo "[4/6] Resolving macOS SDK location..."
SDK_PATH=$(xcrun --show-sdk-path)
echo "      Found SDK at: ${SDK_PATH}"

# 5. Compile native Swift files into optimized binary
echo "[5/6] Compiling optimized Swift binary..."
swiftc -O \
    -sdk "${SDK_PATH}" \
    -o "${MACOS_DIR}/MouseControl" \
    Models.swift \
    AppSettings.swift \
    KeySimulator.swift \
    EventTapManager.swift \
    SettingsView.swift \
    AppDelegate.swift \
    main.swift

# 6. Package property list metadata and assets
echo "[6/6] Packaging Info.plist application metadata and UI resources..."
cp Info.plist "${APP_NAME}/Contents/Info.plist"
if [ -f "mouse_icon.png" ]; then
    cp mouse_icon.png "${RESOURCES_DIR}/mouse_icon.png"
fi

echo ""
echo "============================================="
echo "       Application built successfully!        "
echo "============================================="
echo "Location: $(pwd)/${APP_NAME}"
echo "Launch command: open ${APP_NAME}"
echo "============================================="
