import SwiftUI
import Combine

@main
struct KeySpaApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBar

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private let keyboard = KeyboardLock()
    private(set) var statusItem: NSStatusItem?
    let popover = NSPopover()
    private var lockSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel("KeySpa")
        item.button?.toolTip = "KeySpa — clean your keyboard"

        let content = NSHostingController(rootView: CleaningPanel(keyboard: keyboard))
        content.sizingOptions = [.preferredContentSize]
        popover.contentViewController = content
        popover.contentSize = content.view.fittingSize
        popover.behavior = .transient
        popover.animates = false

        lockSubscription = keyboard.$isLocked.sink { [weak item] locked in
            let image = NSImage(systemSymbolName: locked ? "lock.fill" : "keyboard",
                                accessibilityDescription: locked ? "Keyboard locked" : "KeySpa")
            image?.isTemplate = true
            item?.button?.image = image
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            if let content = popover.contentViewController {
                popover.contentSize = content.view.fittingSize
            }
            // Re-anchor on every open, including after moving the menu bar item.
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboard.unlock()
    }
}

private struct CleaningPanel: View {
    @ObservedObject var keyboard: KeyboardLock
    private let mint = Color(red: 0.46, green: 0.93, blue: 0.79)
    private let ink = Color(red: 0.04, green: 0.17, blue: 0.19)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("KeySpa")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(keyboard.isLocked ? Color.orange : Color.secondary)
                        .frame(width: 5, height: 5)
                    Text(keyboard.isLocked ? "Locked" : "Ready")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            ZStack(alignment: .topTrailing) {
                Image(systemName: "keyboard")
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(.primary)
                    .padding(22)
                    .background(mint.opacity(0.13), in: RoundedRectangle(cornerRadius: 28))
                Image(systemName: keyboard.isLocked ? "lock.fill" : "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 36, height: 36)
                    .background(mint, in: Circle())
                    .offset(x: 8, y: -8)
            }
            .accessibilityHidden(true)
            .padding(.top, 32)
            .padding(.bottom, 24)

            Text(keyboard.isLocked ? "Enjoy a clean slate." : "Time for a clean.")
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .tracking(-0.6)
                .padding(.bottom, 8)

            Text(keyboard.isLocked
                 ? "Keys are paused. Wipe away, then\nuse your mouse to unlock."
                 : "Pause your keys while you clean.\nUnlock whenever you’re ready.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            if let message = keyboard.message {
                VStack(alignment: .leading, spacing: 10) {
                    Text(message)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Accessibility Settings", action: keyboard.openSettings)
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.link)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 16)
            }

            Button {
                if keyboard.isLocked { keyboard.unlock() } else { keyboard.lock() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: keyboard.isLocked ? "lock.open" : "lock")
                    Text(keyboard.isLocked ? "Unlock keyboard" : "Lock keyboard")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(mint, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Image(systemName: "cursorarrow")
                Text("Mouse stays active · Click to unlock")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 22)

            Divider()
            HStack {
                Text("A little keyboard downtime.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    keyboard.unlock()
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 14)
        }
        .padding(24)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)
    }
}
