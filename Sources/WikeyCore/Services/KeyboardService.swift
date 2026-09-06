import AppKit
import CoreGraphics
import Foundation
import OSLog

private let keyboardLogger = Logger(subsystem: "com.wikey.app", category: "keyboard")

@MainActor
struct KeyboardEventEnvironment {
    var hasPermission: () -> Bool
    var keyIsPressed: (CGKeyCode) -> Bool
    var activate: (NSRunningApplication) async throws -> Void
    var isFrontmost: (NSRunningApplication) -> Bool
    var post: (CGKeyCode, CGEventFlags, pid_t) throws -> Void
    var sleep: (Duration) async throws -> Void
    var modifierDiagnostics: () -> String = { "injected environment" }

    static var live: KeyboardEventEnvironment {
        live(postToProcess: { pid, event in event.postToPid(pid) })
    }

    static func live(postToProcess: @escaping (pid_t, CGEvent) -> Void) -> KeyboardEventEnvironment {
        KeyboardEventEnvironment(
            hasPermission: { AXIsProcessTrusted() },
            keyIsPressed: { CGEventSource.keyState(.hidSystemState, key: $0) },
            activate: { try await ApplicationController.activateAndWait($0) },
            isFrontmost: {
                !$0.isTerminated &&
                NSWorkspace.shared.frontmostApplication?.processIdentifier == $0.processIdentifier
            },
            post: { keyCode, flags, pid in
                let (keyDown, keyUp) = try KeyboardEventSender.makeKeyEvents(keyCode: keyCode, flags: flags)
                // Deliver to the validated app's event stream. Re-entering the HID
                // stream lets globally registered Cmd+V/Shift+Enter consume our input.
                // Post the pair without an await so cancellation cannot leave a key down.
                postToProcess(pid, keyDown)
                postToProcess(pid, keyUp)
            },
            sleep: { try await Task.sleep(for: $0) },
            modifierDiagnostics: {
                let hidFlags = CGEventSource.flagsState(.hidSystemState).rawValue
                let sessionFlags = CGEventSource.flagsState(.combinedSessionState).rawValue
                let appKitFlags = NSEvent.modifierFlags.rawValue
                let sessionKeys = KeyboardEventSender.modifierKeyCodes.filter {
                    CGEventSource.keyState(.combinedSessionState, key: $0)
                }
                return "hidFlags=\(hidFlags) sessionFlags=\(sessionFlags) appKitFlags=\(appKitFlags) sessionKeys=\(sessionKeys)"
            }
        )
    }
}

@MainActor
final class KeyboardEventSender {
    // Left/right Command, Shift, Option and Control. Aggregate flags may retain
    // synthetic Cmd+V/Shift+Enter flags even though none of these keys is down.
    static let modifierKeyCodes: [CGKeyCode] = [54, 55, 56, 60, 58, 61, 59, 62]
    private let environment: KeyboardEventEnvironment

    convenience init() {
        self.init(environment: .live)
    }

    init(environment: KeyboardEventEnvironment) {
        self.environment = environment
    }

    func send(
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        into application: NSRunningApplication?,
        settlingDelay: Duration
    ) async throws {
        try Task.checkCancellation()
        guard environment.hasPermission() else {
            throw AutomationError.permissionRequired("손쉬운 사용")
        }
        guard let application else {
            throw AutomationError.inputTargetNotFound
        }

        try await waitForModifierRelease(phase: "beforeActivation")
        try await environment.activate(application)
        // A modifier may have been pressed again during the app switch.
        try await waitForModifierRelease(phase: "afterActivation")
        try Task.checkCancellation()
        guard environment.isFrontmost(application) else {
            throw AutomationError.applicationDidNotActivate(application.localizedName ?? "대상")
        }
        try environment.post(keyCode, flags, application.processIdentifier)
        try await environment.sleep(settlingDelay)
    }

    private func waitForModifierRelease(phase: String) async throws {
        for _ in 0..<150 {
            try Task.checkCancellation()
            if !Self.modifierKeyCodes.contains(where: environment.keyIsPressed) { return }
            try await environment.sleep(.milliseconds(20))
        }
        let downKeys = Self.modifierKeyCodes.filter(environment.keyIsPressed)
        let diagnostics = environment.modifierDiagnostics()
        keyboardLogger.error("Modifier release timeout phase=\(phase, privacy: .public) hidDownKeys=\(String(describing: downKeys), privacy: .public) \(diagnostics, privacy: .public)")
        throw AutomationError.shortcutKeysStillPressed
    }

    static func makeKeyEvents(keyCode: CGKeyCode, flags: CGEventFlags) throws -> (CGEvent, CGEvent) {
        guard let source = CGEventSource(stateID: .privateState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw AutomationError.keyboardEventCreationFailed
        }
        keyDown.flags = flags
        // These modifiers belong only to the synthetic key-down, not the next
        // workflow action. A modifier-bearing key-up can leave HID flags latched.
        keyUp.flags = []
        keyDown.setIntegerValueField(.eventSourceUserData, value: KeyboardService.syntheticEventUserData)
        keyUp.setIntegerValueField(.eventSourceUserData, value: KeyboardService.syntheticEventUserData)
        return (keyDown, keyUp)
    }
}

@MainActor
public final class KeyboardService {
    public nonisolated static let syntheticEventUserData: Int64 = 0x57494B4559
    private let sender: KeyboardEventSender

    public init() {
        sender = KeyboardEventSender()
    }

    init(sender: KeyboardEventSender) {
        self.sender = sender
    }

    public func press(_ key: WorkflowKeyPress, into application: NSRunningApplication?) async throws {
        try await sender.send(
            keyCode: 36,
            flags: key == .shiftEnter ? .maskShift : [],
            into: application,
            settlingDelay: .milliseconds(250)
        )
    }
}
