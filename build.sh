#!/bin/zsh
# Builds Jot.app into ./build and, with --install, copies it to ~/Applications.
set -euo pipefail

cd "$(dirname "$0")"
app="build/Jot.app"
work="build/tmp"

rm -rf "$app" "$work"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$work"

swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 \
    Sources/*.swift Shared/*.swift -o "$app/Contents/MacOS/Jot"

# Compiles the layered icon (light and dark variants) into Assets.car, plus AppIcon.icns for older macOS.
xcrun actool AppIcon.icon --compile "$app/Contents/Resources" \
    --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon \
    --output-partial-info-plist "$work/icon-info.plist" --errors --warnings >/dev/null

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
