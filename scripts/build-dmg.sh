#!/bin/bash
set -euo pipefail
if [[ "$#" != 2 || ! -d "$1/Contents" || "$2" != *.dmg ]]; then
    echo "Usage: $0 /path/to/KeySpa.app /path/to/output.dmg" >&2
    exit 1
fi
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$1" "$staging/KeySpa.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname KeySpa -srcfolder "$staging" -format UDZO -ov "$2"
