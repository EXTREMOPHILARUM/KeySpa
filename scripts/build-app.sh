#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${SIGNING_IDENTITY:-}" && -f .signing-identity ]]; then
    SIGNING_IDENTITY="$(cat .signing-identity)"
fi
build_args=(-c release)
sign_args=(--force --sign "${SIGNING_IDENTITY:--}")
if [[ "${RELEASE_BUILD:-0}" == 1 ]]; then
    : "${SIGNING_IDENTITY:?Release builds require a Developer ID Application identity}"
    build_args+=(--arch arm64 --arch x86_64)
    sign_args+=(--options runtime --timestamp)
fi
swift build "${build_args[@]}"
bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"
app="dist/KeySpa.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/KeySpa" "$app/Contents/MacOS/KeySpa"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/KeySpa.icns "$app/Contents/Resources/KeySpa.icns"
codesign "${sign_args[@]}" "$app"
codesign --verify --strict "$app"
echo "Built $app"
