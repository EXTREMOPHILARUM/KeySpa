#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${1:-}"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 vMAJOR.MINOR.PATCH" >&2
    exit 1
fi
version="${tag#v}"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
if [[ "$version" != "$bundle_version" ]]; then
    echo "Tag $tag does not match Info.plist version $bundle_version" >&2
    exit 1
fi
: "${SIGNING_IDENTITY:?Set the SHA-1 of a Developer ID Application identity}"
: "${APPLE_ID:?Set the Apple ID used for notarization}"
: "${APPLE_TEAM_ID:?Set the Apple Developer team ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set an app-specific password for notarization}"
if ! security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" | grep -q '"Developer ID Application:'; then
    echo "SIGNING_IDENTITY must identify a valid Developer ID Application certificate" >&2
    exit 1
fi

RELEASE_BUILD=1 ./scripts/build-app.sh
app="dist/KeySpa.app"
lipo "$app/Contents/MacOS/KeySpa" -verify_arch arm64 x86_64
signature="$(codesign --display --verbose=4 "$app" 2>&1)"
if ! grep -q '^Authority=Developer ID Application:' <<< "$signature" ||
   ! grep -q 'flags=.*runtime' <<< "$signature" ||
   ! grep -q '^Timestamp=' <<< "$signature"; then
    echo "Release signature must use Developer ID, hardened runtime, and a secure timestamp" >&2
    exit 1
fi

ditto -c -k --keepParent "$app" dist/notarization-upload.zip
xcrun notarytool submit dist/notarization-upload.zip \
    --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait --timeout 30m --output-format json > dist/notarization.json
if ! jq -e '.status == "Accepted"' dist/notarization.json > /dev/null; then
    submission_id="$(jq -r '.id' dist/notarization.json)"
    xcrun notarytool log "$submission_id" \
        --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" dist/notarization-log.json
    echo "Notarization was not accepted; see dist/notarization-log.json" >&2
    exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
archive="KeySpa-${version}-macOS.zip"
ditto -c -k --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS.txt)
echo "Release ready: dist/$archive"
