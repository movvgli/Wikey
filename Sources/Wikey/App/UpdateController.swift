import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateController {
    @ObservationIgnored
    private let standardController: SPUStandardUpdaterController
    @ObservationIgnored
    private let isConfigured: Bool

    private(set) var automaticallyChecksForUpdates = false
    private(set) var automaticallyDownloadsUpdates = false
    private(set) var allowsAutomaticUpdates = false
    private(set) var canCheckForUpdates = false
    private(set) var lastUpdateCheckDate: Date?

    init() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        isConfigured = feedURL?.isEmpty == false && publicKey?.isEmpty == false
        standardController = SPUStandardUpdaterController(
            startingUpdater: isConfigured,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if isConfigured {
            refresh()
            refreshUntilReady()
        }
    }

    func refresh() {
        guard isConfigured else { return }
        let updater = standardController.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        allowsAutomaticUpdates = updater.allowsAutomaticUpdates
        canCheckForUpdates = updater.canCheckForUpdates
        lastUpdateCheckDate = updater.lastUpdateCheckDate
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard isConfigured else { return }
        standardController.updater.automaticallyChecksForUpdates = enabled
        refresh()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        guard isConfigured else { return }
        standardController.updater.automaticallyDownloadsUpdates = enabled
        refresh()
    }

    func checkForUpdates() {
        guard isConfigured else { return }
        standardController.checkForUpdates(nil)
        canCheckForUpdates = false
        refreshUntilReady()
    }

    private func refreshUntilReady() {
        guard isConfigured else { return }
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
