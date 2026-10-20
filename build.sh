#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
version="${VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    echo "VERSION must be X.Y.Z and BUILD_NUMBER must be a positive integer." >&2
    exit 1
fi
identity="${SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | sed -nE 's/^[[:space:]]*[0-9]+\) ([A-F0-9]{40}) .*/\1/p' | head -n 1)}"
if [[ -z "$identity" ]]; then
    echo "An Apple code-signing identity is required for the privileged helper." >&2
    exit 1
fi
swift build -c release "$@"
bin_path=$(swift build -c release "$@" --show-bin-path)
app="$(pwd)/dist/WireGuard Menu.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Library/LaunchDaemons" "$app/Contents/Resources"
cp "$bin_path/WireGuardMenu" "$app/Contents/MacOS/WireGuardMenu"
cp "$bin_path/WireGuardHelper" "$app/Contents/MacOS/WireGuardHelper"
cp LICENSE THIRD_PARTY.md Resources/AppIcon.icns "$app/Contents/Resources/"
cp Resources/se.mnilsson.wireguard-menu.helper.plist "$app/Contents/Library/LaunchDaemons/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>se.mnilsson.wireguard-menu</string>
<key>CFBundleName</key><string>WireGuard Menu</string>
<key>CFBundleExecutable</key><string>WireGuardMenu</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build_number</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --options runtime --timestamp --sign "$identity" --identifier se.mnilsson.wireguard-menu.helper "$app/Contents/MacOS/WireGuardHelper"
codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
