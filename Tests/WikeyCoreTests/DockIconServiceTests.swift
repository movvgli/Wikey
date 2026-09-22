import AppKit
import Foundation
import Testing
@testable import WikeyCore

@MainActor
struct DockIconServiceTests {
    @Test func defaultsToMenuBarOnlyAndPersistsChanges() {
        let suiteName = "DockIconServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var appliedPolicies: [NSApplication.ActivationPolicy] = []
        let service = DockIconService(
            defaults: defaults,
            setActivationPolicy: {
                appliedPolicies.append($0)
                return true
            }
        )

        #expect(service.isVisible == false)
        #expect(DockIconService.savedVisibility(in: defaults) == false)

        service.setVisible(true)

        #expect(service.isVisible == true)
        #expect(DockIconService.savedVisibility(in: defaults) == true)
        #expect(appliedPolicies == [.regular])

        service.setVisible(false)

        #expect(service.isVisible == false)
        #expect(DockIconService.savedVisibility(in: defaults) == false)
        #expect(appliedPolicies == [.regular, .accessory])
    }

    @Test func keepsPreviousPreferenceWhenActivationPolicyCannotChange() {
        let suiteName = "DockIconServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DockIconService(
            defaults: defaults,
            setActivationPolicy: { _ in false }
        )

        service.setVisible(true)

        #expect(service.isVisible == false)
        #expect(DockIconService.savedVisibility(in: defaults) == false)
    }
}
