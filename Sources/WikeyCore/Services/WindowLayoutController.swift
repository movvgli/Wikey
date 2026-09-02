import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

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
public final class WindowLayoutController {
    private let applications: ApplicationController

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
        var failures: [ActionFailure] = []
        for placement in layout.placements {
            do {
                try await apply(placement)
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
        guard let display = availableDisplays.first(where: { $0.target.uuid == placement.display.uuid }) else {
            throw AutomationError.displayNotFound(placement.display.name)
        }

        let app = try await applications.launch(bundleIdentifier: placement.bundleIdentifier, activates: true)
        let window = try await waitForWindow(pid: app.processIdentifier, appName: placement.appName)
        if boolAttribute(window, key: "AXFullScreen" as CFString) == true {
            throw AutomationError.windowIsFullScreen(placement.appName)
        }
        if boolAttribute(window, key: kAXMinimizedAttribute as CFString) == true {
            let value = kCFBooleanFalse as CFTypeRef
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value)
        }

        let cocoaFrame = placement.zone.frame(in: display.visibleFrame)
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        var point = CGPoint(x: cocoaFrame.minX, y: mainTop - cocoaFrame.maxY)
        var size = cocoaFrame.size
        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw AutomationError.windowMoveFailed(placement.appName)
        }

        let positionStatus = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        let sizeStatus = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        guard positionStatus == .success, sizeStatus == .success else {
            throw AutomationError.windowMoveFailed(placement.appName)
        }
    }

    private func waitForWindow(pid: pid_t, appName: String) async throws -> AXUIElement {
        let application = AXUIElementCreateApplication(pid)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let window = firstStandardWindow(application) { return window }
            try? await Task.sleep(for: .milliseconds(200))
        }
        throw AutomationError.windowNotFound(appName)
    }

    private func firstStandardWindow(_ application: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        return windows.first { window in
            stringAttribute(window, key: kAXSubroleAttribute as CFString) == (kAXStandardWindowSubrole as String)
        }
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
