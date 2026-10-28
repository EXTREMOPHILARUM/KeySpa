import AppKit
import ApplicationServices
import Combine

// The tap and observable state are accessed only on the main run loop.
final class KeyboardLock: ObservableObject {
    // Media keys arrive with AppKit's system-defined event type.
    static let systemDefined = CGEventType(rawValue: UInt32(NSEvent.EventType.systemDefined.rawValue))!
    @Published private(set) var isLocked = false
    @Published private(set) var message: String?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var sleepObserver: NSObjectProtocol?

    init() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.unlock() }
    }

    static func blocks(_ type: CGEventType) -> Bool {
        type == .keyDown || type == .keyUp || type == .flagsChanged || type == systemDefined
    }

    func lock() {
        guard !isLocked else { return }
        guard AXIsProcessTrusted() else {
            message = "Allow KeySpa in System Settings → Privacy & Security → Accessibility, then try again."
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            return
        }

        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, Self.systemDefined]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<KeyboardLock>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    owner.unlock()
                    owner.message = "macOS interrupted the keyboard lock. Lock again before cleaning."
                    return Unmanaged.passUnretained(event)
                }
                return owner.isLocked && KeyboardLock.blocks(type) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            message = "Keyboard lock could not start. Check Accessibility access and relaunch KeySpa."
            return
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            message = "Keyboard lock could not start. Try relaunching KeySpa."
            return
        }
        tap = newTap
        source = newSource
        message = nil
        isLocked = true
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
    }

    func unlock() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        isLocked = false
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    deinit {
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let tap { CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }
}
