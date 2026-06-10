#!/bin/bash
set -e

# Premium Header
echo "====================================================="
echo "       🖱️  Installing MouseControl Daemon 🖱️"
echo "====================================================="

TARGET_DIR="$HOME/.mousecontrol"
WEB_DIR="$TARGET_DIR/web"
PLIST_PATH="$HOME/Library/LaunchAgents/com.sahil.mousecontrol.plist"

echo "Creating directories at $TARGET_DIR..."
mkdir -p "$WEB_DIR"

# Repo Base URL for remote fallback if downloaded from other Macs
GITHUB_RAW="https://raw.githubusercontent.com/sahilambekar-ai/mousecontrol/main"

# Copy or download files helper
get_file() {
    local source_file=$1
    local dest_file=$2
    
    # Check if run locally from cloned repo
    if [ -f "$source_file" ]; then
        echo "Copying local $source_file..."
        cp "$source_file" "$dest_file"
    elif [ -f "web/$source_file" ]; then
        echo "Copying local web/$source_file..."
        cp "web/$source_file" "$dest_file"
    else
        # Fallback to remote github repo fetch
        echo "Downloading $source_file from GitHub..."
        # If the file path contains web/, we request it without web/ prefix on raw URL
        local request_url="$GITHUB_RAW/$source_file"
        curl -fsSL "$request_url" -o "$dest_file"
    fi
}

# Fetch all components
get_file "mousecontrol_daemon.swift" "$TARGET_DIR/mousecontrol_daemon.swift"
get_file "index.html" "$WEB_DIR/index.html"
get_file "style.css" "$WEB_DIR/style.css"
get_file "app.js" "$WEB_DIR/app.js"

# Also save install.sh to ~/.mousecontrol/install.sh so the daemon can serve it
if [ -f "install.sh" ]; then
    cp "install.sh" "$TARGET_DIR/install.sh"
else
    curl -fsSL "$GITHUB_RAW/install.sh" -o "$TARGET_DIR/install.sh"
fi

echo "Compiling MouseControl daemon using swiftc..."
swiftc -o "$TARGET_DIR/mousecontrol_daemon" "$TARGET_DIR/mousecontrol_daemon.swift" -framework Cocoa -framework CoreGraphics -framework Network -framework IOKit

# Generate launchd Plist file
echo "Generating launchd agent configuration..."
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sahil.mousecontrol</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_DIR/mousecontrol_daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$TARGET_DIR/daemon.log</string>
    <key>StandardErrorPath</key>
    <string>$TARGET_DIR/daemon.log</string>
</dict>
</plist>
EOF

# Restart the agent in launchd
echo "Registering daemon into launchd session..."
# Unload first if running
launchctl bootout gui/$(id -u)/com.sahil.mousecontrol 2>/dev/null || true
# Bootstrap/load new plist
launchctl bootstrap gui/$(id -u) "$PLIST_PATH"

echo ""
echo "🎉 MouseControl Daemon installed and launched successfully!"
echo "➡️  Go to: http://localhost:9002 to customize your mouse mappings."
echo ""
echo "⚠️  IMPORTANT:"
echo "If this is your first time, macOS will show an Accessibility permission request."
echo "Please navigate to: System Settings -> Privacy & Security -> Accessibility"
echo "and toggle the switch ON for Terminal (or your terminal application)."
echo "====================================================="

# Open the browser to the web configuration panel
open "http://localhost:9002"
