import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateController {
    @ObservationIgnored
    private let standardController: SPUStandardUpdaterController

    private(set) var automaticallyChecksForUpdates = true
    private(set) var automaticallyDownloadsUpdates = false
    private(set) var allowsAutomaticUpdates = false
    private(set) var canCheckForUpdates = false
    private(set) var lastUpdateCheckDate: Date?

    init() {
        standardController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        refresh()
        refreshUntilReady()
    }

    func refresh() {
        let updater = standardController.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        allowsAutomaticUpdates = updater.allowsAutomaticUpdates
        canCheckForUpdates = updater.canCheckForUpdates
        lastUpdateCheckDate = updater.lastUpdateCheckDate
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        standardController.updater.automaticallyChecksForUpdates = enabled
        refresh()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        standardController.updater.automaticallyDownloadsUpdates = enabled
        refresh()
    }

    func checkForUpdates() {
        standardController.checkForUpdates(nil)
        canCheckForUpdates = false
        refreshUntilReady()
    }

    private func refreshUntilReady() {
        Task { @MainActor [weak self] in
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.refresh()
                if self.canCheckForUpdates { return }
            }
        }
    }
}
