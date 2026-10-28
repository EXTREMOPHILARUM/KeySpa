#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077

IFS= read -r -s -p 'Paste the Apple app-specific password (hidden): ' notary_password
printf '\n'
if [[ ! "$notary_password" =~ ^[A-Za-z0-9-]+$ ]]; then
    echo 'Expected an Apple app-specific password containing letters, numbers, and hyphens.' >&2
    exit 1
fi

env_file="$(mktemp .env.XXXXXX)"
trap 'rm -f "$env_file"; unset notary_password' EXIT
if [[ -f .env ]]; then
    awk '!/^(export[[:space:]]+)?APPLE_APP_SPECIFIC_PASSWORD=/' .env > "$env_file"
fi
printf 'APPLE_APP_SPECIFIC_PASSWORD=%s\n' "$notary_password" >> "$env_file"
mv "$env_file" .env
printf '%s' "$notary_password" | gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo EXTREMOPHILARUM/KeySpa
echo 'Saved to local .env (owner-only access) and GitHub Actions secret.'
