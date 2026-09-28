#!/bin/bash
# Builds an unsigned device IPA for OurMoney (macOS + Xcode + XcodeGen required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v xcodebuild >/dev/null || { echo "xcodebuild is required (macOS + Xcode)."; exit 1; }
command -v xcodegen >/dev/null || { echo "xcodegen is required. Install with: brew install xcodegen"; exit 1; }

# Generate GoogleService-Info.plist / GoogleSignIn.xcconfig from env or existing files.
bash Scripts/prepare_config.sh

xcodegen generate
rm -rf build
mkdir -p build/archive build/ipa/Payload
xcodebuild -project OurMoney.xcodeproj -scheme OurMoney -configuration Release -sdk iphoneos \
  -archivePath build/archive/OurMoney.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive

APP="build/archive/OurMoney.xcarchive/Products/Applications/OurMoney.app"
test -d "$APP" || { echo "ERROR: $APP not found in archive"; exit 1; }
BID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
[ "$BID" = "com.ourmoney.app" ] || { echo "ERROR: unexpected bundle id $BID"; exit 1; }

cp -R "$APP" build/ipa/Payload/OurMoney.app
(cd build/ipa && zip -qry ../OurMoney-unsigned.ipa Payload)
echo "Created build/OurMoney-unsigned.ipa (bundle id: com.ourmoney.app, UNSIGNED)"
