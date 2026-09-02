import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class ClipboardService {
    public init() {}

    public func copy(_ document: NSAttributedString) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects([document]) else {
            throw AutomationError.clipboardWriteFailed
        }
    }

    public func paste(into application: NSRunningApplication?) async throws {
        guard AXIsProcessTrusted() else {
            throw AutomationError.permissionRequired("손쉬운 사용")
        }
        application?.activate()
        try? await Task.sleep(for: .milliseconds(180))
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw AutomationError.clipboardWriteFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
