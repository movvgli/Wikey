import Foundation
import Testing
@testable import WikeyCore

@MainActor
struct WikeyRuntimeTests {
    @Test func onlyApplicationRunsPopulateApplicationLaunchErrors() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let runtime = WikeyRuntime(storeRootURL: root)
        let application = ApplicationShortcut(bundleIdentifier: "test.application", displayName: "Test App")
        runtime.store.applicationShortcuts = [application]
        let failure = ActionFailure(actionTitle: "실행", message: "실패")

        runtime.runner.onSummary?(RunSummary(
            workflowID: UUID(), workflowName: "일반 워크플로",
            startedAt: .now, finishedAt: .now, failures: [failure]
        ))
        #expect(runtime.applicationLaunchErrors.isEmpty)
        #expect(runtime.lastRun?.workflowName == "일반 워크플로")

        runtime.runner.onSummary?(RunSummary(
            workflowID: application.id, workflowName: application.displayName,
            startedAt: .now, finishedAt: .now, failures: [failure]
        ))
        #expect(runtime.applicationLaunchError(bundleIdentifier: application.bundleIdentifier) == "실패")
        #expect(runtime.applicationName(runID: application.id) == application.displayName)

        runtime.runner.onSummary?(RunSummary(
            workflowID: application.id, workflowName: application.displayName,
            startedAt: .now, finishedAt: .now, failures: []
        ))
        #expect(runtime.applicationLaunchErrors.isEmpty)
    }
}
