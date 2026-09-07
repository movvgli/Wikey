import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import OSLog
import Observation

private let layoutLogger = Logger(subsystem: "com.wikey.app", category: "layout")

public struct DisplayInfo: Identifiable, Hashable {
    public var id: String { target.uuid }
    public var target: DisplayTarget
    public var visibleFrame: CGRect

    public init(target: DisplayTarget, visibleFrame: CGRect) {
        self.target = target
        self.visibleFrame = visibleFrame
    }
}

@MainActor
@Observable
public final class WindowLayoutController {
    private let applications: ApplicationController
    public private(set) var displayMappings: [String: String] = [:]
    public private(set) var mappingError: String?
    private var mappingsURL: URL?

    public func loadDisplayMappings(from root: URL) {
        let url = root.appendingPathComponent("display-mappings-local.json")
        mappingsURL = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { displayMappings = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url)) }
        catch { mappingError = "이 Mac의 모니터 연결을 다시 설정해 주세요." }
    }

    public func setDisplayMapping(source: String, target: String) {
        guard let mappingsURL else { return }
        do {
            var next = displayMappings
            next[source] = target.isEmpty ? nil : target
            try JSONEncoder().encode(next).write(to: mappingsURL, options: .atomic)
            displayMappings = next; mappingError = nil
        } catch { mappingError = "모니터 연결을 저장하지 못했습니다: \(error.localizedDescription)" }
    }

    public init(applications: ApplicationController) {
        self.applications = applications
    }

    public var availableDisplays: [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(number.uint32Value))?.takeRetainedValue(),
                  let uuidString = CFUUIDCreateString(nil, uuid) as String? else { return nil }
            return DisplayInfo(
                target: DisplayTarget(uuid: uuidString, name: screen.localizedName),
                visibleFrame: screen.visibleFrame
            )
        }
    }

    public func apply(_ layout: WindowLayout) async -> [ActionFailure] {
        guard !layout.placements.isEmpty else {
            return [ActionFailure(
                actionTitle: layout.name,
                message: "레이아웃에 배치할 앱을 먼저 추가해 주세요."
            )]
        }
        var failures: [ActionFailure] = []
        for placement in layout.placements {
            do {
                try Task.checkCancellation()
                try await apply(placement)
            } catch is CancellationError {
                break
            } catch {
                failures.append(ActionFailure(actionTitle: placement.appName, message: error.localizedDescription))
            }
        }
        return failures
    }

    private func apply(_ placement: AppWindowPlacement) async throws {
        guard AXIsProcessTrusted() else {
            throw AutomationError.permissionRequired("손쉬운 사용")
        }
        let displayID = displayMappings[placement.display.uuid] ?? placement.display.uuid
        guard let display = availableDisplays.first(where: { $0.target.uuid == displayID }) else {
            throw AutomationError.displayNotFound(placement.display.name)
        }

        let app = try await applications.launch(bundleIdentifier: placement.bundleIdentifier, activates: true)
        let window = try await waitForWindow(pid: app.processIdentifier, appName: placement.appName)
        AXUIElementSetMessagingTimeout(window, 1)
        let currentDisplayFrame = availableDisplays.first(where: { $0.target.uuid == displayID })?.visibleFrame
        layoutLogger.info("Placement target bundle=\(placement.bundleIdentifier, privacy: .public) zone=\(placement.zone.rawValue, privacy: .public) visibleBeforeActivation=\(NSStringFromRect(display.visibleFrame), privacy: .public) visibleAfterActivation=\(currentDisplayFrame.map(NSStringFromRect) ?? "missing", privacy: .public)")
        let cocoaFrame = placement.zone.frame(in: display.visibleFrame)
        // AX coordinates are relative to the primary display, not the display
        // containing the active window (NSScreen.main).
        guard let primaryScreen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                == CGMainDisplayID()
        }) ?? NSScreen.screens.first else {
            throw AutomationError.windowMoveFailed(placement.appName)
        }
        let frame = LayoutWindowPlacement.accessibilityFrame(cocoaFrame, primaryDisplayFrame: primaryScreen.frame)
        try await LayoutWindowPlacement.apply(
            to: AccessibilityLayoutWindow(
                element: window,
                application: AXUIElementCreateApplication(app.processIdentifier)
            ),
            frame: frame,
            appName: placement.appName
        )
    }

    private func waitForWindow(pid: pid_t, appName: String) async throws -> AXUIElement {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 1)
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        while clock.now < deadline {
            try Task.checkCancellation()
            if let window = firstStandardWindow(application) { return window }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw AutomationError.windowNotFound(appName)
    }

    private func firstStandardWindow(_ application: AXUIElement) -> AXUIElement? {
        let windows = attribute(application, key: kAXWindowsAttribute as CFString) as? [AXUIElement] ?? []
        let focused = windowAttribute(application, key: kAXFocusedWindowAttribute as CFString)
        let main = windowAttribute(application, key: kAXMainWindowAttribute as CFString)
        // Some apps expose their focused window before AXWindows is populated.
        var candidates = windows
        for window in [focused, main].compactMap({ $0 }) where !candidates.contains(where: { CFEqual($0, window) }) {
            candidates.append(window)
        }
        let standardWindows = candidates.filter { window in
            stringAttribute(window, key: kAXSubroleAttribute as CFString) == (kAXStandardWindowSubrole as String)
        }
        let selection = standardWindows.map { window in
            LayoutWindowSelection(
                isFocused: focused.map { CFEqual(window, $0) } ?? false,
                isMain: main.map { CFEqual(window, $0) } ?? false,
                isMinimized: boolAttribute(window, key: kAXMinimizedAttribute as CFString) == true
            )
        }
        guard let index = LayoutWindowSelection.preferredIndex(in: selection) else { return nil }
        return standardWindows[index]
    }

    private func attribute(_ element: AXUIElement, key: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key, &value) == .success else { return nil }
        return value
    }

    private func windowAttribute(_ element: AXUIElement, key: CFString) -> AXUIElement? {
        guard let value = attribute(element, key: key), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func stringAttribute(_ element: AXUIElement, key: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key, &value) == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, key: CFString) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key, &value) == .success else { return nil }
        return value as? Bool
    }
}

/// Keep window choice and placement behavior testable without changing real windows.
struct LayoutWindowSelection {
    var isFocused: Bool
    var isMain: Bool
    var isMinimized: Bool

    static func preferredIndex(in windows: [Self]) -> Int? {
        windows.firstIndex { $0.isFocused && !$0.isMinimized }
            ?? windows.firstIndex { $0.isMain && !$0.isMinimized }
            ?? windows.firstIndex { !$0.isMinimized }
            ?? windows.firstIndex { $0.isFocused }
            ?? windows.firstIndex { $0.isMain }
            ?? windows.indices.first
    }
}

@MainActor
protocol LayoutWindowAccess {
    var isFullScreen: Bool { get }
    var isMinimized: Bool { get }
    var frame: CGRect? { get }
    var diagnostics: String { get }
    var enhancedUserInterface: Bool? { get }
    func setEnhancedUserInterface(_ enabled: Bool)
    func restore() -> Bool
    func setPosition(_ point: CGPoint)
    func setSize(_ size: CGSize)
    func raise()
}

extension LayoutWindowAccess {
    var diagnostics: String { "unavailable" }
    var enhancedUserInterface: Bool? { nil }
    func setEnhancedUserInterface(_ enabled: Bool) {}
}

enum LayoutWindowPlacement {
    static func accessibilityFrame(_ cocoaFrame: CGRect, primaryDisplayFrame: CGRect) -> CGRect {
        CGRect(
            x: cocoaFrame.minX,
            y: primaryDisplayFrame.maxY - cocoaFrame.maxY,
            width: cocoaFrame.width,
            height: cocoaFrame.height
        )
    }

    static func matches(_ actual: CGRect, _ requested: CGRect) -> Bool {
        abs(actual.minX - requested.minX) <= 2
            && abs(actual.minY - requested.minY) <= 2
            && abs(actual.width - requested.width) <= 2
            && abs(actual.height - requested.height) <= 2
    }

    @MainActor
    static func apply(
        to window: any LayoutWindowAccess,
        frame: CGRect,
        appName: String,
        attempts: Int = 10,
        retryDelay: Duration = .milliseconds(150)
    ) async throws {
        try Task.checkCancellation()
        layoutLogger.info("Placement begin requested=\(NSStringFromRect(frame), privacy: .public) actual=\(window.frame.map(NSStringFromRect) ?? "unavailable", privacy: .public) minimized=\(window.isMinimized) fullScreen=\(window.isFullScreen)")
        guard !window.isFullScreen else { throw AutomationError.windowIsFullScreen(appName) }
        if window.isMinimized {
            guard window.restore() else { throw AutomationError.windowMoveFailed(appName) }
            for _ in 0..<max(1, attempts) {
                try Task.checkCancellation()
                if !window.isMinimized { break }
                try await Task.sleep(for: retryDelay)
            }
            guard !window.isMinimized else { throw AutomationError.windowMoveFailed(appName) }
        }

        // Enhanced accessibility can make AppKit animate each AX frame setter.
        // Match the established window-manager workaround, scoped to this move.
        let shouldRestoreEnhancedUI = window.enhancedUserInterface == true
        if shouldRestoreEnhancedUI {
            window.setEnhancedUserInterface(false)
        }
        defer {
            if shouldRestoreEnhancedUI { window.setEnhancedUserInterface(true) }
        }

        for attempt in 0..<max(1, attempts) {
            try Task.checkCancellation()
            // A large window may be clamped when moved to a smaller display.
            // Resize first, then move; repeat after the app has processed AX.
            window.setSize(frame.size)
            window.setPosition(frame.origin)
            window.setSize(frame.size)
            try await Task.sleep(for: retryDelay)
            let actual = window.frame
            layoutLogger.debug("Placement attempt=\(attempt + 1) requested=\(NSStringFromRect(frame), privacy: .public) actual=\(actual.map(NSStringFromRect) ?? "unavailable", privacy: .public) ax=\(window.diagnostics, privacy: .public)")
            if let actual, matches(actual, frame) {
                window.raise()
                layoutLogger.info("Placement complete actual=\(NSStringFromRect(actual), privacy: .public) attempts=\(attempt + 1) ax=\(window.diagnostics, privacy: .public)")
                return
            }
        }
        // AX setters can report success while the app ignores them or enforces
        // a minimum size. Do not report success before checking the real frame.
        layoutLogger.error("Placement failed requested=\(NSStringFromRect(frame), privacy: .public) actual=\(window.frame.map(NSStringFromRect) ?? "unavailable", privacy: .public) ax=\(window.diagnostics, privacy: .public)")
        throw AutomationError.windowMoveFailed(appName)
    }
}

@MainActor
private final class AccessibilityLayoutWindow: LayoutWindowAccess {
    let element: AXUIElement
    let application: AXUIElement
    private var positionStatus: AXError?
    private var sizeStatus: AXError?
    private var readPositionStatus: AXError?
    private var readSizeStatus: AXError?

    init(element: AXUIElement, application: AXUIElement) {
        self.element = element
        self.application = application
    }

    var diagnostics: String {
        "setPosition=\(positionStatus?.rawValue.description ?? "not-attempted") setSize=\(sizeStatus?.rawValue.description ?? "not-attempted") readPosition=\(readPositionStatus?.rawValue.description ?? "not-attempted") readSize=\(readSizeStatus?.rawValue.description ?? "not-attempted")"
    }

    var isFullScreen: Bool { attribute("AXFullScreen" as CFString) as? Bool == true }
    var isMinimized: Bool { attribute(kAXMinimizedAttribute as CFString) as? Bool == true }

    var enhancedUserInterface: Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, "AXEnhancedUserInterface" as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    func setEnhancedUserInterface(_ enabled: Bool) {
        let status = AXUIElementSetAttributeValue(
            application, "AXEnhancedUserInterface" as CFString,
            enabled ? kCFBooleanTrue : kCFBooleanFalse
        )
        layoutLogger.debug("Enhanced UI change requested=\(enabled) succeeded=\(status == .success) ax=\(status.rawValue)")
    }

    var frame: CGRect? {
        guard let position = attribute(kAXPositionAttribute as CFString),
              let size = attribute(kAXSizeAttribute as CFString),
              CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    func restore() -> Bool {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success
    }

    func setPosition(_ point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        positionStatus = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    func setSize(_ size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        sizeStatus = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    private func attribute(_ key: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, key, &value)
        if key == kAXPositionAttribute as CFString { readPositionStatus = status }
        if key == kAXSizeAttribute as CFString { readSizeStatus = status }
        guard status == .success else { return nil }
        return value
    }
}
