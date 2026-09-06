import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import WikeyCore

@MainActor
struct KeyboardServiceTests {
    @Test func waitsForModifierKeyReleaseThenSendsPlainEnter() async throws {
        let fixture = KeyboardFixture()
        fixture.modifierChecksRemaining = 3
        let service = KeyboardService(sender: fixture.sender())
        try await service.press(.enter, into: .current)

        #expect(fixture.events == ["sleep", "sleep", "sleep", "activate", "post", "sleep"])
        #expect(fixture.posted.first?.0 == 36)
        #expect(fixture.posted.first?.1 == [])
    }

    @Test func shiftEnterHasOnlyShiftModifier() async throws {
        let fixture = KeyboardFixture()
        let service = KeyboardService(sender: fixture.sender())
        try await service.press(.shiftEnter, into: .current)

        #expect(fixture.posted.first?.0 == 36)
        #expect(fixture.posted.first?.1 == .maskShift)
    }

    @Test func heldShortcutTimesOutWithoutTyping() async {
        let fixture = KeyboardFixture()
        fixture.modifierChecksRemaining = 151
        let service = KeyboardService(sender: fixture.sender())

        await #expect(throws: AutomationError.self) {
            try await service.press(.enter, into: .current)
        }
        #expect(fixture.posted.isEmpty)
        #expect(!fixture.events.contains("activate"))
    }

    @Test func lostFocusStopsBeforePosting() async {
        let fixture = KeyboardFixture()
        fixture.frontmost = false
        let service = KeyboardService(sender: fixture.sender())

        await #expect(throws: AutomationError.self) {
            try await service.press(.enter, into: .current)
        }
        #expect(fixture.posted.isEmpty)
    }

    @Test func cancellationWhileWaitingDoesNotSendInput() async {
        let fixture = KeyboardFixture()
        fixture.modifierChecksRemaining = 1
        fixture.sleepError = CancellationError()
        let service = KeyboardService(sender: fixture.sender())

        await #expect(throws: CancellationError.self) {
            try await service.press(.enter, into: .current)
        }
        #expect(fixture.posted.isEmpty)
        #expect(!fixture.events.contains("activate"))
    }

    @Test func missingPermissionDoesNotActivateOrType() async {
        let fixture = KeyboardFixture()
        fixture.permission = false
        let service = KeyboardService(sender: fixture.sender())

        await #expect(throws: AutomationError.self) {
            try await service.press(.enter, into: .current)
        }
        #expect(fixture.events.isEmpty)
    }

    @Test func missingInputTargetDoesNotTypeIntoUnknownApp() async {
        let fixture = KeyboardFixture()
        let service = KeyboardService(sender: fixture.sender())

        await #expect(throws: AutomationError.self) {
            try await service.press(.enter, into: nil)
        }
        #expect(fixture.events.isEmpty)
    }

    @Test func pasteUsesCommandVAndWaitsBeforeReturning() async throws {
        let fixture = KeyboardFixture()
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard, sender: fixture.sender())
        try service.copy(NSAttributedString(string: "Sample"))
        try await service.paste(into: .current)

        #expect(fixture.posted.first?.0 == 9)
        #expect(fixture.posted.first?.1 == .maskCommand)
        #expect(fixture.events == ["activate", "post", "sleep"])
        #expect(fixture.delays.last == .milliseconds(500))
    }

    @Test func pasteThenShiftEnterDoesNotTreatSyntheticFlagsAsHeldKeys() async throws {
        var aggregateFlags: CGEventFlags = []
        var queriedKeys: Set<CGKeyCode> = []
        var posted: [(CGKeyCode, CGEventFlags)] = []
        var modifierWaitCount = 0
        let sender = KeyboardEventSender(environment: KeyboardEventEnvironment(
            hasPermission: { true },
            keyIsPressed: {
                queriedKeys.insert($0)
                // This fixture reports no held modifier in the key-state table,
                // while its aggregate flag table retains the preceding flags.
                return false
            },
            activate: { _ in },
            isFrontmost: { _ in true },
            post: { keyCode, flags, _ in
                posted.append((keyCode, flags))
                aggregateFlags = flags
            },
            sleep: {
                if $0 == .milliseconds(20) { modifierWaitCount += 1 }
            }
        ))
        let clipboard = ClipboardService(pasteboard: .withUniqueName(), sender: sender)
        let keyboard = KeyboardService(sender: sender)

        try clipboard.copy(NSAttributedString(string: "ALPHA"))
        try await clipboard.paste(into: .current)
        #expect(aggregateFlags == .maskCommand)
        try await keyboard.press(.shiftEnter, into: .current)
        #expect(aggregateFlags == .maskShift)
        try await keyboard.press(.enter, into: .current)

        #expect(posted.map(\.0) == [9, 36, 36])
        #expect(posted.map(\.1) == [.maskCommand, .maskShift, []])
        #expect(queriedKeys == Set([54, 55, 56, 60, 58, 61, 59, 62]))
        #expect(modifierWaitCount == 0)
    }

    @Test(arguments: [54, 55, 56, 60, 58, 61, 59, 62] as [CGKeyCode])
    func eachModifierKeyBlocksInputUntilReleased(_ heldKey: CGKeyCode) async throws {
        var heldKeys: Set<CGKeyCode> = [heldKey]
        var postedCount = 0
        var waitCount = 0
        let sender = KeyboardEventSender(environment: KeyboardEventEnvironment(
            hasPermission: { true },
            keyIsPressed: { heldKeys.contains($0) },
            activate: { _ in },
            isFrontmost: { _ in true },
            post: { _, _, _ in
                #expect(heldKeys.isEmpty)
                postedCount += 1
            },
            sleep: {
                if $0 == .milliseconds(20) {
                    waitCount += 1
                    #expect(postedCount == 0)
                    heldKeys.removeAll()
                }
            }
        ))

        try await KeyboardService(sender: sender).press(.enter, into: .current)
        #expect(waitCount == 1)
        #expect(postedCount == 1)
    }

    @Test func syntheticEventPairReleasesModifierFlagsAndKeepsBypassMarker() throws {
        let (down, up) = try KeyboardEventSender.makeKeyEvents(keyCode: 9, flags: .maskCommand)
        #expect(down.type == .keyDown)
        #expect(up.type == .keyUp)
        #expect(down.flags == .maskCommand)
        #expect(up.flags.isEmpty)
        #expect(down.getIntegerValueField(.keyboardEventKeycode) == 9)
        #expect(up.getIntegerValueField(.keyboardEventKeycode) == 9)
        #expect(down.getIntegerValueField(.eventSourceUserData) == KeyboardService.syntheticEventUserData)
        #expect(up.getIntegerValueField(.eventSourceUserData) == KeyboardService.syntheticEventUserData)
    }

    @Test func pasteAndEnterPairsGoOnlyToTheValidatedTargetProcessInOrder() async throws {
        var delivered: [(pid_t, CGEventType, Int64, CGEventFlags)] = []
        var foregroundChecks = 0
        let application = NSRunningApplication.current
        var environment = KeyboardEventEnvironment.live(postToProcess: { pid, event in
            #expect(foregroundChecks > 0)
            delivered.append((pid, event.type, event.getIntegerValueField(.keyboardEventKeycode), event.flags))
        })
        environment.hasPermission = { true }
        environment.keyIsPressed = { _ in false }
        environment.activate = { _ in }
        environment.isFrontmost = { target in
            foregroundChecks += 1
            return target.processIdentifier == application.processIdentifier
        }
        environment.sleep = { _ in }
        let sender = KeyboardEventSender(environment: environment)
        let clipboard = ClipboardService(pasteboard: .withUniqueName(), sender: sender)
        let keyboard = KeyboardService(sender: sender)

        try clipboard.copy(NSAttributedString(string: "ALPHA"))
        try await clipboard.paste(into: application)
        try await keyboard.press(.shiftEnter, into: application)
        try await keyboard.press(.enter, into: application)

        #expect(delivered.map(\.0) == Array(repeating: application.processIdentifier, count: 6))
        #expect(delivered.map(\.1) == [.keyDown, .keyUp, .keyDown, .keyUp, .keyDown, .keyUp])
        #expect(delivered.map(\.2) == [9, 9, 36, 36, 36, 36])
        #expect(delivered.map(\.3) == [.maskCommand, [], .maskShift, [], [], []])
        #expect(foregroundChecks == 3)
    }

    @Test func liveEventTransportIsNeverCalledWhenTargetLosesFocus() async {
        var deliveredCount = 0
        var environment = KeyboardEventEnvironment.live(postToProcess: { _, _ in deliveredCount += 1 })
        environment.hasPermission = { true }
        environment.keyIsPressed = { _ in false }
        environment.activate = { _ in }
        environment.isFrontmost = { _ in false }
        environment.sleep = { _ in }

        await #expect(throws: AutomationError.self) {
            try await KeyboardService(sender: KeyboardEventSender(environment: environment))
                .press(.enter, into: .current)
        }
        #expect(deliveredCount == 0)
    }
}

@MainActor
private final class KeyboardFixture {
    var events: [String] = []
    var posted: [(CGKeyCode, CGEventFlags)] = []
    var delays: [Duration] = []
    var modifierChecksRemaining = 0
    var permission = true
    var frontmost = true
    var sleepError: Error?

    func sender() -> KeyboardEventSender {
        KeyboardEventSender(environment: KeyboardEventEnvironment(
            hasPermission: { self.permission },
            keyIsPressed: { _ in
                guard self.modifierChecksRemaining > 0 else { return false }
                self.modifierChecksRemaining -= 1
                return true
            },
            activate: { _ in self.events.append("activate") },
            isFrontmost: { _ in self.frontmost },
            post: { keyCode, flags, _ in
                self.events.append("post")
                self.posted.append((keyCode, flags))
            },
            sleep: {
                self.events.append("sleep")
                self.delays.append($0)
                if let error = self.sleepError { throw error }
            }
        ))
    }
}
