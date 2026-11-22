#!/usr/bin/env bash
# Archive, sign and upload Dumbo to TestFlight using an App Store Connect API key.
# Env: APPLE_TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (contents of the .p8 file).
# SCREEN_TIME=1 signs with Family Controls (needs Apple's distribution approval); default is 0.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APPLE_TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8:?}"
SCREEN_TIME="${SCREEN_TIME:-0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
OUT="${OUT:-build-testflight}"

KEY_PATH="$(mktemp -d)/AuthKey_${ASC_KEY_ID}.p8"
printf '%s\n' "$ASC_KEY_P8" > "$KEY_PATH"
trap 'rm -f "$KEY_PATH"' EXIT
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

SUFFIX="-nost"
[ "$SCREEN_TIME" = "1" ] && SUFFIX=""

xcodegen generate
rm -rf "$OUT"
xcodebuild archive \
  -project Dumbo.xcodeproj -scheme Dumbo -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Dumbo.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DUMBO_ENT_SUFFIX="$SUFFIX" \
  "${AUTH[@]}"

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>${DESTINATION:-upload}</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath "$OUT/Dumbo.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" "${AUTH[@]}"
echo "Uploaded build $BUILD_NUMBER (Screen Time: $SCREEN_TIME)"
