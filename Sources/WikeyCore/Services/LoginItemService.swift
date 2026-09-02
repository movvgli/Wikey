import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
public final class LoginItemService {
    public static let helperIdentifier = "com.wikey.login-helper"

    public private(set) var status: SMAppService.Status = .notRegistered
    public private(set) var lastError: String?

    private var service: SMAppService {
        SMAppService.loginItem(identifier: Self.helperIdentifier)
    }

    public init() {
        refresh()
    }

    public var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    public func refresh() {
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() }
            else { try service.unregister() }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
