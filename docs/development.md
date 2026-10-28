# Developing KeySpa

Requires macOS 14+ and Xcode 15+ or compatible Swift command line tools. The app has no external dependencies.

## Build and run

```sh
./scripts/build-app.sh
open dist/KeySpa.app
```

Open `Package.swift` in Xcode to work on the source. Use the bundled `.app` for permission testing; `swift run` uses a different executable location. Move the app to its intended installation location before granting Accessibility access.

Builds use `SIGNING_IDENTITY`, or the certificate name/hash in the Git-ignored `.signing-identity` file. Without either, they are ad-hoc signed. To keep Accessibility access across local rebuilds, select a certificate from `security find-identity -v -p codesigning` and save its hash in `.signing-identity`. Keep using the same identity and app location.

When changing signing identities, quit KeySpa, remove the old Accessibility entry, then add and enable the current app once. A listed entry can refer to an older build even when enabled. Development signing is for local use; public releases require Developer ID signing and Apple notarization.

## How it works

A Core Graphics session event tap discards keyboard down/up events, modifier changes, and system-defined events while locked. Pointer events pass through so users can unlock from the menu bar. No keystrokes are recorded, stored, or sent anywhere. If macOS disables the tap, KeySpa releases the lock and shows a message.

The interface uses SwiftUI, hosted in an AppKit popover anchored to the status button. It measures its contents before opening to avoid positioning an empty panel.

## Verify

```sh
swift test
./scripts/test-release.sh
./scripts/build-app.sh
codesign --verify --strict dist/KeySpa.app
./scripts/build-dmg.sh dist/KeySpa.app /tmp/KeySpa-local.dmg
```

The last command checks DMG packaging locally; it does not sign or notarize the image. See [releases.md](releases.md) for the public release pipeline.

Manual acceptance checklist:

- Deny Accessibility: locking shows instructions and stays unlocked.
- Grant access: lock, open a disposable text document with the mouse, and confirm ordinary keys and modifiers do not type or trigger shortcuts.
- Check media keys on your hardware. Do not press the power button.
- Click Unlock and confirm typing resumes.
- Lock again, wait more than five minutes, and confirm the keyboard stays locked until you click Unlock.
- Confirm quit and sleep both release the lock.
- Mount the downloaded DMG, copy the app to Applications, and test the installed copy.
