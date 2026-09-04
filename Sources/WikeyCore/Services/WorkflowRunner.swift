import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class WorkflowRunner {
    public private(set) var runningWorkflowID: UUID?
    public private(set) var queuedWorkflowIDs: [UUID] = []
    public var onSummary: ((RunSummary) -> Void)?

    private let store: WikeyStore
    private let applications: ApplicationController
    private let clipboard: ClipboardService
    private let keyboard: KeyboardService
    private let layouts: WindowLayoutController

    public init(
        store: WikeyStore,
        applications: ApplicationController,
        clipboard: ClipboardService,
        keyboard: KeyboardService,
        layouts: WindowLayoutController
    ) {
        self.store = store
        self.applications = applications
        self.clipboard = clipboard
        self.keyboard = keyboard
        self.layouts = layouts
    }

    public func submit(workflowID: UUID) {
        guard store.workflows.contains(where: { $0.id == workflowID }) else { return }
        if runningWorkflowID == workflowID || queuedWorkflowIDs.contains(workflowID) { return }
        queuedWorkflowIDs.append(workflowID)
        if runningWorkflowID == nil {
            Task { await drainQueue() }
        }
    }

    private func drainQueue() async {
        while !queuedWorkflowIDs.isEmpty {
            let workflowID = queuedWorkflowIDs.removeFirst()
            guard let workflow = store.workflows.first(where: { $0.id == workflowID }) else { continue }
            runningWorkflowID = workflowID
            let summary = await run(workflow)
            onSummary?(summary)
            runningWorkflowID = nil
        }
    }

    private func run(_ workflow: Workflow) async -> RunSummary {
        let startedAt = Date()
        let originalApplication = applications.frontmostApplication()
        let failures = await runActions(
            workflow.actions,
            originalApplication: originalApplication,
            executionStack: [workflow.id]
        )

        return RunSummary(
            workflowName: workflow.name,
            startedAt: startedAt,
            finishedAt: Date(),
            failures: failures
        )
    }

    private func runActions(
        _ actions: [WorkflowAction],
        originalApplication: NSRunningApplication?,
        executionStack: [UUID]
    ) async -> [ActionFailure] {
        var failures: [ActionFailure] = []

        for action in actions {
            do {
                switch action {
                case .launchApplication(let bundleIdentifier, _):
                    _ = try await applications.launch(bundleIdentifier: bundleIdentifier)

                case .openURL(let url):
                    try await applications.openURL(url)

                case .copyTemplate(let templateID, let mode):
                    guard store.templates.contains(where: { $0.id == templateID }) else {
                        throw AutomationError.templateNotFound
                    }
                    let document = store.templateDocument(id: templateID)
                    try clipboard.copy(document)
                    if mode == .copyAndPaste {
                        try await clipboard.paste(into: originalApplication)
                    }

                case .applyLayout(let layoutID):
                    guard let layout = store.layouts.first(where: { $0.id == layoutID }) else {
                        throw AutomationError.layoutNotFound
                    }
                    let layoutFailures = await layouts.apply(layout)
                    failures.append(contentsOf: layoutFailures.map {
                        ActionFailure(actionTitle: "\(action.title) · \($0.actionTitle)", message: $0.message)
                    })

                case .pressKey(let key):
                    try await keyboard.press(key, into: originalApplication)

                case .runWorkflow(let workflowID):
                    guard !executionStack.contains(workflowID) else {
                        throw AutomationError.workflowCycleDetected
                    }
                    guard let nestedWorkflow = store.workflows.first(where: { $0.id == workflowID }) else {
                        throw AutomationError.workflowNotFound
                    }
                    let nestedFailures = await runActions(
                        nestedWorkflow.actions,
                        originalApplication: originalApplication,
                        executionStack: executionStack + [workflowID]
                    )
                    failures.append(contentsOf: nestedFailures.map {
                        ActionFailure(
                            actionTitle: "\(nestedWorkflow.name) · \($0.actionTitle)",
                            message: $0.message
                        )
                    })

                case .pasteImages(let filePaths):
                    try clipboard.copyImages(at: filePaths)
                    try await clipboard.paste(into: originalApplication)

                case .pasteFiles(let filePaths):
                    try clipboard.copyFiles(at: filePaths)
                    try await clipboard.paste(into: originalApplication)
                }
            } catch {
                failures.append(ActionFailure(actionTitle: action.title, message: error.localizedDescription))
            }
        }

        return failures
    }
}
