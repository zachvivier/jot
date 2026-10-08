#!/bin/zsh
# Archives Jot for iPhone and uploads it to TestFlight. The build number is the current date and time.
set -euo pipefail

cd "$(dirname "$0")"
build_number=$(date +%y%m%d.%H%M)

rm -rf build
xcodegen generate --quiet
xcodebuild -project Jot.xcodeproj -scheme Jot -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/Jot.xcarchive \
    -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$build_number" archive
xcodebuild -exportArchive -archivePath build/Jot.xcarchive \
    -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
echo "Uploaded build $build_number. It appears in TestFlight once Apple finishes processing."
