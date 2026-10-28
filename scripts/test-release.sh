#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
export FIXTURE_DIR="$fixture_root/project with spaces"
mkdir -p "$FIXTURE_DIR"/{scripts,Resources,bin,mocks}
cp scripts/build-app.sh scripts/build-dmg.sh scripts/release.sh scripts/configure-notarization.sh "$FIXTURE_DIR/scripts/"
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
  lipo)
    [[ "$#" == 2 && "$1" == -archs && -f "$2" ]]
    echo "${MOCK_ARCHITECTURES:-arm64 x86_64}" ;;
  ditto) cp -R "$1" "$2" ;;
  hdiutil)
    [[ "${MOCK_DMG_FAILURE:-0}" == 0 ]] || exit 1
    test -d "$5/KeySpa.app/Contents"
    test "$(readlink "$5/Applications")" = /Applications
    echo "dmg layout verified" >> "$FIXTURE_DIR/calls"
    touch "${@: -1}" ;;
  xcrun)
    if [[ "$1 $2" == 'notarytool submit' ]]; then
      [[ "$3" == *.dmg && -f "$3" ]]
      [[ "${MOCK_NOTARY_TIMEOUT:-0}" == 0 ]] || exit 1
      printf '{"id":"test-submission","status":"%s"}\n' "${MOCK_NOTARY_STATUS:-Accepted}"
    elif [[ "$1 $2" == 'notarytool log' ]]; then
      echo '{}' > "${@: -1}"
    else
      echo "$*" >> "$FIXTURE_DIR/calls"
    fi ;;
  spctl)
    [[ "$2 $3 $4 $5" == '--type open --context context:primary-signature' ]]
    [[ "${MOCK_GATEKEEPER_REJECTED:-0}" == 0 ]] || exit 1
    echo 'spctl accepted' >> "$FIXTURE_DIR/calls" ;;
  gh)
    [[ "$*" == 'secret set APPLE_APP_SPECIFIC_PASSWORD --repo EXTREMOPHILARUM/KeySpa' ]]
    cat > "$FIXTURE_DIR/uploaded-secret" ;;
esac
MOCK
chmod +x "$FIXTURE_DIR/mocks/tool"
for tool in swift security codesign lipo ditto hdiutil xcrun spctl gh; do
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
    test ! -f "$FIXTURE_DIR/dist/SHA256SUMS.txt"
}

expect_failure "$FIXTURE_DIR/scripts/release.sh" invalid-tag
expect_failure "$FIXTURE_DIR/scripts/release.sh" v999.999.999
expect_failure env APPLE_APP_SPECIFIC_PASSWORD= "$FIXTURE_DIR/scripts/release.sh" "v$version"
expect_failure env MOCK_CERTIFICATE_KIND='Apple Development' "$FIXTURE_DIR/scripts/release.sh" "v$version"
expect_failure env MOCK_ARCHITECTURES=arm64 "$FIXTURE_DIR/scripts/release.sh" "v$version"
expect_failure env MOCK_DMG_FAILURE=1 "$FIXTURE_DIR/scripts/release.sh" "v$version"
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
grep -q 'dmg layout verified' "$FIXTURE_DIR/calls"
grep -q -- '--timestamp dist/KeySpa-.*-macOS.dmg' "$FIXTURE_DIR/calls"

printf 'OTHER_SETTING=keep\n' > "$FIXTURE_DIR/.env"
for password in fixture-password-one fixture-password-two; do
    printf '%s\n' "$password" | "$FIXTURE_DIR/scripts/configure-notarization.sh" > "$fixture_root/output" 2>&1
    grep -Fxq "APPLE_APP_SPECIFIC_PASSWORD=$password" "$FIXTURE_DIR/.env"
    test "$(cat "$FIXTURE_DIR/uploaded-secret")" = "$password"
    if grep -Fq "$password" "$fixture_root/output"; then
        echo 'Password was exposed in output' >&2
        exit 1
    fi
done
grep -Fxq 'OTHER_SETTING=keep' "$FIXTURE_DIR/.env"
test "$(grep -c '^APPLE_APP_SPECIFIC_PASSWORD=' "$FIXTURE_DIR/.env")" = 1
test "$(stat -f '%Lp' "$FIXTURE_DIR/.env")" = 600
if printf 'invalid value\n' | "$FIXTURE_DIR/scripts/configure-notarization.sh" > "$fixture_root/output" 2>&1; then
    echo 'Expected invalid password input to fail' >&2
    exit 1
fi
echo 'Release checks passed (mock signing/notarization; no credentials used).'
