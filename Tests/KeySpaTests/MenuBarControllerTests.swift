import AppKit
import XCTest
@testable import KeySpa

final class MenuBarControllerTests: XCTestCase {
    @MainActor
    func testPopoverOpensAtStatusButtonAndTogglesClosed() throws {
        let app = NSApplication.shared
        let controller = MenuBarController()
        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: app))
        let item = try XCTUnwrap(controller.statusItem)
        let button = try XCTUnwrap(item.button)
        // XCTest has no visible menu bar window; give the anchor a visible host.
        let window = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 100, height: 60),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        button.removeFromSuperview()
        window.contentView?.addSubview(button)
        window.orderFrontRegardless()
        defer {
            controller.popover.close()
            window.orderOut(nil)
            NSStatusBar.system.removeStatusItem(item)
        }

        XCTAssertEqual(controller.popover.contentSize.width, 320)
        XCTAssertGreaterThan(controller.popover.contentSize.height, 0)
        XCTAssertEqual(controller.popover.contentSize,
                       controller.popover.contentViewController?.view.fittingSize)
        controller.togglePopover()
        XCTAssertTrue(controller.popover.isShown)
        XCTAssertEqual(controller.popover.positioningRect, button.bounds)
        controller.togglePopover()
        XCTAssertFalse(controller.popover.isShown)
    }
}
