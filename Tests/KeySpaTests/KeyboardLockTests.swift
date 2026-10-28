import XCTest
import CoreGraphics
@testable import KeySpa

final class KeyboardLockTests: XCTestCase {
    func testKeyboardEventsAreBlockedAndPointerEventsPassThrough() {
        for type: CGEventType in [.keyDown, .keyUp, .flagsChanged, KeyboardLock.systemDefined] {
            XCTAssertTrue(KeyboardLock.blocks(type))
        }
        for type: CGEventType in [.leftMouseDown, .leftMouseUp, .mouseMoved, .scrollWheel, .rightMouseDown] {
            XCTAssertFalse(KeyboardLock.blocks(type))
        }
    }

    func testUnlockIsSafeWhenAlreadyUnlocked() {
        let keyboard = KeyboardLock()
        keyboard.unlock()
        keyboard.unlock()
        XCTAssertFalse(keyboard.isLocked)
    }
}
