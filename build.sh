#!/bin/zsh
# Builds Jot.app into ./build and, with --install, copies it to ~/Applications.
set -euo pipefail

cd "$(dirname "$0")"
app="build/Jot.app"
work="build/tmp"

rm -rf "$app" "$work"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$work/AppIcon.iconset"

swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 \
    Sources/*.swift -o "$app/Contents/MacOS/Jot"

swift make-icon.swift "$work/icon.png"
for px in 16 32 128 256 512; do
    sips -z $px $px "$work/icon.png" --out "$work/AppIcon.iconset/icon_${px}x${px}.png" >/dev/null
    sips -z $((px * 2)) $((px * 2)) "$work/icon.png" --out "$work/AppIcon.iconset/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"

cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
rm -rf "$work"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/Jot.app
    cp -R "$app" ~/Applications/
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/Jot.app
    echo "Installed ~/Applications/Jot.app"
fi
