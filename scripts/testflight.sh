#!/usr/bin/env bash
# Archive, sign and upload Dumbo to TestFlight using an App Store Connect API key.
# Env: APPLE_TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (contents of the .p8 file).
# APP_GROUP=0 signs without the App Group if it isn't linked to the bundle IDs yet.
# SCREEN_TIME=1 signs with Family Controls (needs Apple's distribution approval); default is 0.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APPLE_TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8:?}"
SCREEN_TIME="${SCREEN_TIME:-0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
OUT="${OUT:-build-testflight}"

KEY_PATH="$(mktemp -d)/AuthKey_${ASC_KEY_ID}.p8"
if printf '%s' "$ASC_KEY_P8" | grep -q 'BEGIN PRIVATE KEY'; then
  printf '%s\n' "$ASC_KEY_P8" > "$KEY_PATH"
else
  # Accept the bare base64 body too.
  { echo "-----BEGIN PRIVATE KEY-----"; printf '%s' "$ASC_KEY_P8" | tr -d ' \n\r' | fold -w 64; echo; echo "-----END PRIVATE KEY-----"; } > "$KEY_PATH"
fi
trap 'rm -f "$KEY_PATH"' EXIT

SUFFIX="-nost"
[ "$SCREEN_TIME" = "1" ] && SUFFIX=""
# APP_GROUP=0 signs without the shared App Group (widgets show no data; Screen Time unavailable).
WIDGETS_SUFFIX=""
[ "${APP_GROUP:-1}" = "0" ] && SUFFIX="-bare" && WIDGETS_SUFFIX="-bare"

BUNDLES=(com.sarthib7.dumbo com.sarthib7.dumbo.widgets com.sarthib7.dumbo.monitor)
python3 scripts/asc_profiles.py "$KEY_PATH" "${BUNDLES[@]}"

xcodegen generate
rm -rf "$OUT"
xcodebuild archive \
  -project Dumbo.xcodeproj -scheme Dumbo -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Dumbo.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DUMBO_ENT_SUFFIX="$SUFFIX" DUMBO_WIDGETS_ENT_SUFFIX="$WIDGETS_SUFFIX" \
  DUMBO_SCREEN_TIME="$([ "$SCREEN_TIME" = "1" ] && echo YES || echo NO)" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution"

PROFILES=""
for b in "${BUNDLES[@]}"; do PROFILES+="<key>$b</key><string>Dumbo AppStore $b</string>"; done
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key><dict>${PROFILES}</dict>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath "$OUT/Dumbo.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist"

[ "${UPLOAD:-1}" = "1" ] || { echo "Exported $OUT/export/Dumbo.ipa (not uploaded)"; exit 0; }
API_PRIVATE_KEYS_DIR="$(dirname "$KEY_PATH")" xcrun altool --upload-app -t ios -f "$OUT/export/Dumbo.ipa" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "Uploaded build $BUILD_NUMBER (Screen Time: $SCREEN_TIME)"
