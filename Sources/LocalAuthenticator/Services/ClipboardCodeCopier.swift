import AppKit
import Foundation

protocol StringPasteboard: AnyObject {
    @discardableResult
    func clearContents() -> Int

    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool

    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
}

extension NSPasteboard: StringPasteboard {}

enum ClipboardCodeCopier {
    typealias Scheduler = (_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Void

    @MainActor
    static func copy(
        _ code: String,
        to pasteboard: StringPasteboard = NSPasteboard.general,
        clearDelay: TimeInterval = 30,
        scheduler: Scheduler? = nil
    ) {
        pasteboard.clearContents()
        guard pasteboard.setString(code, forType: .string) else {
            return
        }

        let schedule = scheduler ?? defaultScheduler
        schedule(clearDelay) {
            guard pasteboard.string(forType: .string) == code else {
                return
            }

            pasteboard.clearContents()
        }
    }

    private static func defaultScheduler(
        delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                action()
            }
        }
    }
}
