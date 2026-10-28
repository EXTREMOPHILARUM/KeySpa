# KeySpa

**A little downtime for your keyboard.**

<img src="../Resources/KeySpa.png" width="128" alt="KeySpa: a mint keyboard with sparkles">

A tiny SwiftUI menu bar app for cleaning your Mac keyboard. Click **Lock keyboard**, wipe your keys, then click **Unlock keyboard**. Your mouse and trackpad keep working. There is no time limit. Sleep and quitting the app also release the lock.

## Run

Requires macOS 14+ and Xcode 15+ (or compatible Swift command line tools).

```sh
./scripts/build-app.sh
open dist/KeySpa.app
```

Move the app to `/Applications` before granting permissions if you want to keep it installed. Click the keyboard icon in the menu bar. The first lock attempt asks for **System Settings → Privacy & Security → Accessibility** access. Enable KeySpa, then click Lock again. If macOS does not pick up the permission change, quit and reopen the app.

Open `Package.swift` in Xcode to work on the code. Use the bundled `.app` for permission testing; `swift run` uses a different executable location.

## How it works

A Core Graphics session event tap discards keyboard down/up events, modifier changes, and system-defined events while locked. No keystrokes are recorded, stored, or sent anywhere. Pointer events pass through so you can unlock from the menu bar. If macOS disables the tap, KeySpa releases the lock and shows a message.

This is a cleaning aid, not a security lock. Power/Touch ID, OS-reserved shortcuts, and input in secure system contexts may still act. System-defined events include media keys; behavior varies by hardware. Avoid the power button while cleaning.

## Verify

```sh
swift test
./scripts/build-app.sh
codesign --verify --strict dist/KeySpa.app
```

Manual acceptance checklist:

- Deny Accessibility: locking must show instructions and stay unlocked.
- Grant access: lock, open a disposable text document with the mouse, and confirm ordinary keys and modifiers do not type or trigger shortcuts.
- Check media keys on your hardware. Do not test by pressing the power button.
- Click Unlock and confirm typing resumes.
- Lock again, wait more than five minutes, and confirm the keyboard stays locked until you click Unlock.
- Confirm quit and sleep both release the lock.

## Open source

MIT licensed. No dependencies, analytics, or background services.

Repository: [EXTREMOPHILARUM/KeySpa](https://github.com/EXTREMOPHILARUM/KeySpa). See [Releasing KeySpa](releases.md) for CI, Developer ID signing, Apple notarization, required secrets, and version tags. Public release ZIPs include Apple Silicon and Intel binaries plus SHA-256 checksums. A release is published only after signing, notarization, stapling, and Gatekeeper verification succeed.

Builds use `SIGNING_IDENTITY`, or the certificate name/hash in a local `.signing-identity` file (ignored by Git). Without either, the build is ad-hoc signed. To keep Accessibility access across local rebuilds, select a certificate from `security find-identity -v -p codesigning` and save its hash in `.signing-identity`. Keep using that identity and the same app location.

When switching from ad-hoc signing to certificate signing, quit KeySpa, remove its old Accessibility entry, then add and enable the current app once. A listed entry can refer to an older build even when its switch is enabled.

Public downloadable releases should use Developer ID signing and Apple notarization. Apple Development signing is suitable for local development; ad-hoc builds can trigger Gatekeeper and rebuilds may require regranting Accessibility access.
