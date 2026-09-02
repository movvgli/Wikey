import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class PermissionCenter {
    public private(set) var accessibilityGranted = false
    public private(set) var inputMonitoringGranted = false
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    public init() {
        refresh()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    public func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        scheduleRefresh()
    }

    public func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self else { return }
            self.refresh()
            if !self.inputMonitoringGranted {
                self.openInputMonitoringSettings()
            }
        }
    }

    public func openAccessibilitySettings() {
        openSettings(anchor: "Privacy_Accessibility")
    }

    public func openInputMonitoringSettings() {
        openSettings(anchor: "Privacy_ListenEvent")
    }

    private func openSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func scheduleRefresh() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refresh()
        }
    }
}
