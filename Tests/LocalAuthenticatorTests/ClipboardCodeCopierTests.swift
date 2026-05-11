import AppKit
import XCTest
@testable import LocalAuthenticator

@MainActor
final class ClipboardCodeCopierTests: XCTestCase {
    func testClearsCopiedCodeWhenPasteboardIsUnchanged() {
        let pasteboard = FakeStringPasteboard()
        var scheduledActions: [@MainActor () -> Void] = []

        ClipboardCodeCopier.copy("123456", to: pasteboard) { delay, action in
            XCTAssertEqual(delay, 30)
            scheduledActions.append(action)
        }

        XCTAssertEqual(pasteboard.value, "123456")

        scheduledActions.first?()

        XCTAssertNil(pasteboard.value)
    }

    func testDoesNotClearPasteboardWhenUserCopiedAnotherValue() {
        let pasteboard = FakeStringPasteboard()
        var scheduledActions: [@MainActor () -> Void] = []

        ClipboardCodeCopier.copy("123456", to: pasteboard) { _, action in
            scheduledActions.append(action)
        }

        pasteboard.setString("autre valeur", forType: .string)
        scheduledActions.first?()

        XCTAssertEqual(pasteboard.value, "autre valeur")
    }
}

private final class FakeStringPasteboard: StringPasteboard {
    private(set) var value: String?

    @discardableResult
    func clearContents() -> Int {
        value = nil
        return 0
    }

    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        value = string
        return true
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        value
    }
}
