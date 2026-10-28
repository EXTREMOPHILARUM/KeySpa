#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
export FIXTURE_DIR="$fixture_root/project with spaces"
mkdir -p "$FIXTURE_DIR"/{scripts,Resources,bin,mocks}
cp scripts/build-app.sh scripts/release.sh "$FIXTURE_DIR/scripts/"
cp Resources/Info.plist Resources/KeySpa.icns "$FIXTURE_DIR/Resources/"
touch "$FIXTURE_DIR/bin/KeySpa"
cat > "$FIXTURE_DIR/mocks/tool" <<'MOCK'
#!/bin/bash
set -euo pipefail
case "$(basename "$0")" in
  swift)
    if [[ "$*" == *--show-bin-path* ]]; then
      echo "$FIXTURE_DIR/bin"
    else
      echo "swift $*" >> "$FIXTURE_DIR/calls"
    fi ;;
  security)
    echo "1) ABC123 \"${MOCK_CERTIFICATE_KIND:-Developer ID Application}: Test (TEAM)\"" ;;
  codesign)
    if [[ "$1" == --display ]]; then
      printf 'Authority=Developer ID Application: Test (TEAM)\nCodeDirectory flags=0x10000(runtime)\nTimestamp=Test\n'
    else
      echo "codesign $*" >> "$FIXTURE_DIR/calls"
    fi ;;
  lipo) echo "lipo $*" >> "$FIXTURE_DIR/calls" ;;
  ditto) touch "${@: -1}" ;;
  xcrun)
    if [[ "$1 $2" == 'notarytool submit' ]]; then
      [[ "${MOCK_NOTARY_TIMEOUT:-0}" == 0 ]] || exit 1
      printf '{"id":"test-submission","status":"%s"}\n' "${MOCK_NOTARY_STATUS:-Accepted}"
    elif [[ "$1 $2" == 'notarytool log' ]]; then
      echo '{}' > "${@: -1}"
    else
      echo "$*" >> "$FIXTURE_DIR/calls"
    fi ;;
  spctl)
    [[ "${MOCK_GATEKEEPER_REJECTED:-0}" == 0 ]] || exit 1
    echo 'spctl accepted' >> "$FIXTURE_DIR/calls" ;;
esac
MOCK
chmod +x "$FIXTURE_DIR/mocks/tool"
for tool in swift security codesign lipo ditto xcrun spctl; do
    ln -s tool "$FIXTURE_DIR/mocks/$tool"
done
export PATH="$FIXTURE_DIR/mocks:$PATH"
export SIGNING_IDENTITY=ABC123 APPLE_ID=test@example.invalid APPLE_TEAM_ID=TEAM
export APPLE_APP_SPECIFIC_PASSWORD=fixture-password
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"

expect_failure() {
    rm -rf "$FIXTURE_DIR/dist"
    if "$@" > "$fixture_root/output" 2>&1; then
        echo "Expected failure: $*" >&2
        exit 1
    fi
    test ! -f "$FIXTURE_DIR/dist/KeySpa-$version-macOS.zip"
}

expect_failure "$FIXTURE_DIR/scripts/release.sh" invalid-tag
expect_failure "$FIXTURE_DIR/scripts/release.sh" v999.999.999
expect_failure env APPLE_APP_SPECIFIC_PASSWORD= "$FIXTURE_DIR/scripts/release.sh" "v$version"
expect_failure env MOCK_CERTIFICATE_KIND='Apple Development' "$FIXTURE_DIR/scripts/release.sh" "v$version"
expect_failure env MOCK_NOTARY_STATUS=Invalid "$FIXTURE_DIR/scripts/release.sh" "v$version"
test -f "$FIXTURE_DIR/dist/notarization-log.json"
expect_failure env MOCK_NOTARY_TIMEOUT=1 "$FIXTURE_DIR/scripts/release.sh" "v$version"
expect_failure env MOCK_GATEKEEPER_REJECTED=1 "$FIXTURE_DIR/scripts/release.sh" "v$version"
rm -rf "$FIXTURE_DIR/dist"
"$FIXTURE_DIR/scripts/release.sh" "v$version" > "$fixture_root/output" 2>&1
(cd "$FIXTURE_DIR/dist" && shasum -a 256 -c SHA256SUMS.txt)
grep -q -- '--arch arm64 --arch x86_64' "$FIXTURE_DIR/calls"
grep -q -- '--options runtime --timestamp' "$FIXTURE_DIR/calls"
grep -q 'stapler validate' "$FIXTURE_DIR/calls"
grep -q 'spctl accepted' "$FIXTURE_DIR/calls"
echo 'Release checks passed (mock signing/notarization; no credentials used).'
