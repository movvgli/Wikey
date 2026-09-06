import CoreGraphics
import Testing
@testable import WikeyCore

struct WindowLayoutControllerTests {
    @Test @MainActor func emptyLayoutReportsActionableFailureBeforeLaunchingApps() async {
        let controller = WindowLayoutController(applications: ApplicationController())
        let failures = await controller.apply(WindowLayout(name: "빈 레이아웃"))
        #expect(failures.count == 1)
        #expect(failures.first?.actionTitle == "빈 레이아웃")
        #expect(failures.first?.message == "레이아웃에 배치할 앱을 먼저 추가해 주세요.")
    }

    @Test func focusedWindowWinsOverUnorderedAXWindowList() {
        let windows = [
            LayoutWindowSelection(isFocused: false, isMain: true, isMinimized: false),
            LayoutWindowSelection(isFocused: true, isMain: false, isMinimized: false),
        ]
        #expect(LayoutWindowSelection.preferredIndex(in: windows) == 1)
    }

    @Test func visibleWindowWinsOverStaleMinimizedMainWindow() {
        let windows = [
            LayoutWindowSelection(isFocused: true, isMain: true, isMinimized: true),
            LayoutWindowSelection(isFocused: false, isMain: false, isMinimized: false),
        ]
        #expect(LayoutWindowSelection.preferredIndex(in: windows) == 1)
        #expect(LayoutWindowSelection.preferredIndex(in: Array(windows.prefix(1))) == 0)
        #expect(LayoutWindowSelection.preferredIndex(in: []) == nil)
    }

    @Test func restoresMainWindowWhenEveryWindowIsMinimized() {
        let windows = [
            LayoutWindowSelection(isFocused: false, isMain: false, isMinimized: true),
            LayoutWindowSelection(isFocused: false, isMain: true, isMinimized: true),
        ]
        #expect(LayoutWindowSelection.preferredIndex(in: windows) == 1)
    }

    @Test func convertsExternalDisplaysAboveAndLeftOfPrimary() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let left = CGRect(x: -1920, y: 50, width: 960, height: 1000)
        let above = CGRect(x: 20, y: 900, width: 1440, height: 860)
        #expect(LayoutWindowPlacement.accessibilityFrame(left, primaryDisplayFrame: primary)
            == CGRect(x: -1920, y: -150, width: 960, height: 1000))
        #expect(LayoutWindowPlacement.accessibilityFrame(above, primaryDisplayFrame: primary)
            == CGRect(x: 20, y: -860, width: 1440, height: 860))
    }

    @Test @MainActor func waitsForMinimizedWindowToRestoreBeforeResizing() async throws {
        let window = FakeLayoutWindow()
        window.minimized = true
        let target = CGRect(x: 100, y: 40, width: 640, height: 800)
        try await LayoutWindowPlacement.apply(to: window, frame: target, appName: "Test", retryDelay: .zero)
        #expect(window.events == ["restore", "size", "position", "size", "raise"])
        #expect(!window.mutatedWhileMinimized)
        #expect(window.frame == target)
    }

    @Test @MainActor func retriesWhenAppInitiallyIgnoresResize() async throws {
        let window = FakeLayoutWindow()
        window.ignoredResizeAttempts = 2
        let target = CGRect(x: -900, y: 60, width: 640, height: 800)
        try await LayoutWindowPlacement.apply(to: window, frame: target, appName: "Test", retryDelay: .zero)
        #expect(window.events == ["size", "position", "size", "size", "position", "size", "raise"])
        #expect(window.frame == target)
    }

    @Test @MainActor func reportsFailureIfAppDoesNotAcceptRequestedFrame() async {
        let window = FakeLayoutWindow()
        window.ignoredResizeAttempts = 100
        do {
            try await LayoutWindowPlacement.apply(
                to: window, frame: CGRect(x: 0, y: 0, width: 640, height: 800),
                appName: "Test", attempts: 2, retryDelay: .zero
            )
            Issue.record("A successful AX call must not count as a successfully applied layout.")
        } catch AutomationError.windowMoveFailed(let app) {
            #expect(app == "Test")
            #expect(!window.events.contains("raise"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func fullScreenWindowIsNotSilentlyChanged() async {
        let window = FakeLayoutWindow()
        window.isFullScreen = true
        do {
            try await LayoutWindowPlacement.apply(to: window, frame: .zero, appName: "Test", retryDelay: .zero)
            Issue.record("Full screen placement should report its limitation.")
        } catch AutomationError.windowIsFullScreen {
            #expect(window.events.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func failedRestoreDoesNotTryToMoveHiddenWindow() async {
        let window = FakeLayoutWindow()
        window.minimized = true
        window.canRestore = false
        do {
            try await LayoutWindowPlacement.apply(to: window, frame: .zero, appName: "Test", retryDelay: .zero)
            Issue.record("A minimized window must be restored before placement.")
        } catch AutomationError.windowMoveFailed {
            #expect(window.events == ["restore"])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func cancellationStopsPendingPlacementRetries() async {
        let window = FakeLayoutWindow()
        window.ignoredResizeAttempts = 100
        let task = Task {
            try await LayoutWindowPlacement.apply(
                to: window, frame: CGRect(x: 0, y: 0, width: 640, height: 800),
                appName: "Test", retryDelay: .seconds(30)
            )
        }
        while window.events.isEmpty { await Task.yield() }
        task.cancel()
        do {
            try await task.value
            Issue.record("Cancellation should stop pending placement.")
        } catch is CancellationError {
            #expect(window.events == ["size", "position", "size"])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func restoresEnhancedUIAfterSuccessfulPlacement() async throws {
        let window = FakeLayoutWindow()
        window.enhancedUserInterface = true
        try await LayoutWindowPlacement.apply(
            to: window, frame: CGRect(x: 10, y: 30, width: 640, height: 800),
            appName: "Test", retryDelay: .zero
        )
        #expect(window.enhancedUserInterface == true)
        #expect(window.events.first == "enhanced:false")
        #expect(window.events.last == "enhanced:true")
    }

    @Test @MainActor func restoresEnhancedUIAfterFailedPlacement() async {
        let window = FakeLayoutWindow()
        window.enhancedUserInterface = true
        window.ignoredResizeAttempts = 100
        do {
            try await LayoutWindowPlacement.apply(
                to: window, frame: CGRect(x: 0, y: 0, width: 640, height: 800),
                appName: "Test", attempts: 1, retryDelay: .zero
            )
            Issue.record("The fake app should reject the requested frame.")
        } catch AutomationError.windowMoveFailed {
            #expect(window.enhancedUserInterface == true)
            #expect(window.events.first == "enhanced:false")
            #expect(window.events.last == "enhanced:true")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func restoresEnhancedUIAfterCancellation() async {
        let window = FakeLayoutWindow()
        window.enhancedUserInterface = true
        window.ignoredResizeAttempts = 100
        let task = Task {
            try await LayoutWindowPlacement.apply(
                to: window, frame: CGRect(x: 0, y: 0, width: 640, height: 800),
                appName: "Test", retryDelay: .seconds(30)
            )
        }
        while !window.events.contains("position") { await Task.yield() }
        task.cancel()
        do {
            try await task.value
            Issue.record("Cancellation should stop pending placement.")
        } catch is CancellationError {
            #expect(window.enhancedUserInterface == true)
            #expect(window.events.last == "enhanced:true")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func leavesDisabledEnhancedUIUntouched() async throws {
        let window = FakeLayoutWindow()
        window.enhancedUserInterface = false
        try await LayoutWindowPlacement.apply(
            to: window, frame: CGRect(x: 10, y: 30, width: 640, height: 800),
            appName: "Test", retryDelay: .zero
        )
        #expect(window.enhancedUserInterface == false)
        #expect(!window.events.contains(where: { $0.hasPrefix("enhanced:") }))
    }
}

@MainActor
private final class FakeLayoutWindow: LayoutWindowAccess {
    var isFullScreen = false
    var minimized = false
    var canRestore = true
    var restoreReadsRemaining = 0
    var ignoredResizeAttempts = 0
    var enhancedUserInterface: Bool?
    var events: [String] = []
    var mutatedWhileMinimized = false
    var storedFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)

    var isMinimized: Bool {
        if restoreReadsRemaining > 0 {
            restoreReadsRemaining -= 1
            return true
        }
        return minimized
    }
    var frame: CGRect? { storedFrame }

    func restore() -> Bool {
        events.append("restore")
        guard canRestore else { return false }
        minimized = false
        restoreReadsRemaining = 3
        return true
    }

    func setPosition(_ point: CGPoint) {
        events.append("position")
        mutatedWhileMinimized = mutatedWhileMinimized || minimized || restoreReadsRemaining > 0
        storedFrame.origin = point
    }

    func setSize(_ size: CGSize) {
        events.append("size")
        mutatedWhileMinimized = mutatedWhileMinimized || minimized || restoreReadsRemaining > 0
        if ignoredResizeAttempts > 0 { ignoredResizeAttempts -= 1 }
        else { storedFrame.size = size }
    }

    func raise() { events.append("raise") }

    func setEnhancedUserInterface(_ enabled: Bool) {
        events.append("enhanced:\(enabled)")
        enhancedUserInterface = enabled
    }
}
