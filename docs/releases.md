# Releasing KeySpa

The public repository is [EXTREMOPHILARUM/KeySpa](https://github.com/EXTREMOPHILARUM/KeySpa).

## Pipeline

Pull requests and pushes to `main` run the Swift tests, mocked release checks, and a local app build on macOS 15 with Xcode 16.4. CI uses ad-hoc signing and does not receive release credentials.

Pushing a version tag runs the release workflow:

1. Verify that the tag exists, matches the checked-out commit and `CFBundleShortVersionString`, and has the form `vMAJOR.MINOR.PATCH`.
2. Run all tests.
3. Import the distribution certificate into a temporary keychain. The import action removes that keychain after the job.
4. Build a universal macOS 14+ app for Apple Silicon and Intel. Sign with **Developer ID Application**, hardened runtime, and a secure timestamp.
5. Submit to Apple notarization and wait for acceptance. A rejection or timeout fails the job.
6. Staple and validate the notarization ticket, then assess the app with Gatekeeper.
7. Package the stapled app as `KeySpa-VERSION-macOS.zip`, generate `SHA256SUMS.txt`, upload both files to a draft release, then publish it. An interrupted upload leaves a draft, not a public release.

Failed signing, notarization, or Gatekeeper checks prevent publication. A development-signed app is not a public release. Release credentials are used only by tag or manually dispatched release jobs, never pull request jobs. Actions are pinned to commit hashes.

## One-time credentials

You need a paid Apple Developer team and a **Developer ID Application** certificate with its private key. Apple Development and Apple Distribution certificates do not qualify for this workflow. If Developer ID creation is unavailable in Xcode, the team's Account Holder needs to create the certificate.

Export only the Developer ID Application identity to an encrypted `.p12` file, including its private key. Store these repository secrets using `gh secret set --repo EXTREMOPHILARUM/KeySpa`:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64 of the encrypted `.p12` containing one Developer ID Application identity |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `APPLE_ID` | Apple account email authorized for notarization |
| `APPLE_TEAM_ID` | The team owning the signing certificate |
| `APPLE_APP_SPECIFIC_PASSWORD` | An app-specific password created for notarization, not the Apple account password |

Use stdin or an interactive secret prompt; do not put credentials in commits, command history, release assets, or chat. For the certificate, pipe `base64 -i /path/to/certificate.p12` into `gh secret set DEVELOPER_ID_CERTIFICATE_BASE64 --repo EXTREMOPHILARUM/KeySpa`. Keep the private key and export password backed up securely. GitHub Actions receives a copy of the signing identity through encrypted secrets.

Local certificate choices stay in `.signing-identity` and are ignored by Git. The release workflow explicitly selects the certificate imported into its temporary keychain.

## Publish a version

Update both `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`. Use `MAJOR.MINOR.PATCH` for the former and an increasing build number for the latter. Commit and push the version change, and confirm CI passes before tagging:

```sh
swift test
./scripts/test-release.sh
git tag v0.1.0
git push origin v0.1.0
gh run list --workflow release.yml --repo EXTREMOPHILARUM/KeySpa
```

Use a new version for each release. Never move a published tag. A failed release can be retried from the Actions UI or with `gh workflow run release.yml --repo EXTREMOPHILARUM/KeySpa -f tag=v0.1.0`. If upload failed and left a draft, delete that incomplete draft (keep its Git tag) before retrying. If publication succeeded, use a new version instead of rerunning it.

To build locally with the same pipeline, export the four signing/notarization environment variables used by `scripts/release.sh`, then run `./scripts/release.sh v0.1.0`. The script prepares the verified ZIP and checksum but does not publish to GitHub. A notary rejection writes `dist/notarization-log.json` for inspection. A timeout fails closed; check the existing submission with `notarytool` before resubmitting.

## Verification limits

The mocked shell tests verify failure handling and packaging without contacting Apple. Swift tests cover event filtering and panel anchoring. Neither proves that a notarized download passes Gatekeeper on another Mac or that keyboard blocking works with that Mac's permissions and hardware. Perform those checks on the downloaded release before recommending it to users. Intel is cross-compiled; running it on an Intel Mac remains a separate check.
