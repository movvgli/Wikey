import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class KeyboardService {
    public init() {}

    public func press(_ key: WorkflowKeyPress, into application: NSRunningApplication?) async throws {
        guard AXIsProcessTrusted() else {
            throw AutomationError.permissionRequired("손쉬운 사용")
        }

        application?.activate()
        try? await Task.sleep(for: .milliseconds(140))

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) else {
            throw AutomationError.keyboardEventCreationFailed
        }

        if key == .shiftEnter {
            keyDown.flags = .maskShift
            keyUp.flags = .maskShift
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
