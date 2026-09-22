import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class DockIconService {
    public static let preferenceKey = "showsDockIcon"

    public private(set) var isVisible: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool

    public convenience init() {
        self.init(
            defaults: .standard,
            setActivationPolicy: { NSApplication.shared.setActivationPolicy($0) }
        )
    }

    init(
        defaults: UserDefaults,
        setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Bool
    ) {
        self.defaults = defaults
        self.setActivationPolicy = setActivationPolicy
        self.isVisible = Self.savedVisibility(in: defaults)
    }

    public func setVisible(_ visible: Bool) {
        guard setActivationPolicy(Self.activationPolicy(for: visible)) else { return }
        defaults.set(visible, forKey: Self.preferenceKey)
        isVisible = visible
    }

    public static func savedVisibility(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: preferenceKey)
    }

    public static func activationPolicy(for visible: Bool) -> NSApplication.ActivationPolicy {
        visible ? .regular : .accessory
    }
}
