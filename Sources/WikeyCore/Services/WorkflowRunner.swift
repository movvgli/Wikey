import AppKit
import Foundation
import Observation

@MainActor
protocol WorkflowApplicationControlling {
    func inputTargetApplication() -> NSRunningApplication?
    func launch(bundleIdentifier: String, activates: Bool) async throws -> NSRunningApplication
    func openURL(_ value: String) async throws -> NSRunningApplication
}

@MainActor
protocol WorkflowClipboardControlling {
    func copy(_ document: NSAttributedString) throws
    func copyImages(at filePaths: [String]) throws
    func copyFiles(at filePaths: [String]) throws
    func paste(into application: NSRunningApplication?) async throws
}

@MainActor
protocol WorkflowKeyboardControlling {
    func press(_ key: WorkflowKeyPress, into application: NSRunningApplication?) async throws
}

@MainActor
protocol WorkflowLayoutControlling {
    func apply(_ layout: WindowLayout) async -> [ActionFailure]
}

extension ApplicationController: WorkflowApplicationControlling {}
extension ClipboardService: WorkflowClipboardControlling {}
extension KeyboardService: WorkflowKeyboardControlling {}
extension WindowLayoutController: WorkflowLayoutControlling {}

@MainActor
@Observable
public final class WorkflowRunner {
    public private(set) var runningWorkflowID: UUID?
    public private(set) var currentActionTitle: String?
    public private(set) var queuedWorkflowIDs: [UUID] = []
    public var onSummary: ((RunSummary) -> Void)?

    private struct PendingRun {
        var workflow: Workflow
        var inputTarget: NSRunningApplication?
    }

    private final class ExecutionContext {
        var inputTarget: NSRunningApplication?

        init(inputTarget: NSRunningApplication?) {
            self.inputTarget = inputTarget
        }
    }

    private let store: WikeyStore
    private let applications: any WorkflowApplicationControlling
    private let clipboard: any WorkflowClipboardControlling
    private let keyboard: any WorkflowKeyboardControlling
    private let layouts: any WorkflowLayoutControlling
    @ObservationIgnored private var queue: [PendingRun] = []
    @ObservationIgnored private var drainTask: Task<Void, Never>?

    public convenience init(
        store: WikeyStore,
        applications: ApplicationController,
        clipboard: ClipboardService,
        keyboard: KeyboardService,
        layouts: WindowLayoutController
    ) {
        self.init(
            store: store,
            applicationService: applications,
            clipboardService: clipboard,
            keyboardService: keyboard,
            layoutService: layouts
        )
    }

    init(
        store: WikeyStore,
        applicationService: any WorkflowApplicationControlling,
        clipboardService: any WorkflowClipboardControlling,
        keyboardService: any WorkflowKeyboardControlling,
        layoutService: any WorkflowLayoutControlling
    ) {
        self.store = store
        self.applications = applicationService
        self.clipboard = clipboardService
        self.keyboard = keyboardService
        self.layouts = layoutService
    }

    public func submit(workflowID: UUID) {
        guard let workflow = store.workflows.first(where: { $0.id == workflowID }) else { return }
        submit(workflow: workflow)
    }

    /// Direct app/layout shortcuts use the same queue without saving a temporary workflow.
    public func submit(workflow: Workflow) {
        guard runningWorkflowID != workflow.id, !queuedWorkflowIDs.contains(workflow.id) else { return }
        queue.append(PendingRun(workflow: workflow, inputTarget: applications.inputTargetApplication()))
        queuedWorkflowIDs.append(workflow.id)

        // Claim the worker synchronously. Checking runningWorkflowID here lets multiple
        // submissions create workers before the first asynchronous task starts.
        guard drainTask == nil else { return }
        drainTask = Task { await drainQueue() }
    }

    public func cancel() {
        queue.removeAll()
        queuedWorkflowIDs.removeAll()
        drainTask?.cancel()
    }

    private func drainQueue() async {
        defer {
            runningWorkflowID = nil
            currentActionTitle = nil
            drainTask = nil
            // A new request may arrive while the cancelled worker is unwinding.
            if !queue.isEmpty {
                drainTask = Task { await drainQueue() }
            }
        }
        while !queue.isEmpty && !Task.isCancelled {
            let pending = queue.removeFirst()
            queuedWorkflowIDs.removeFirst()
            runningWorkflowID = pending.workflow.id
            let summary = await run(pending)
            currentActionTitle = nil
            onSummary?(summary)
            runningWorkflowID = nil
        }
    }

    private func run(_ pending: PendingRun) async -> RunSummary {
        let startedAt = Date()
        let context = ExecutionContext(inputTarget: pending.inputTarget)
        let failures = await runActions(
            pending.workflow.actions,
            context: context,
            executionStack: [pending.workflow.id]
        )

        return RunSummary(
            workflowID: pending.workflow.id,
            workflowName: pending.workflow.name,
            startedAt: startedAt,
            finishedAt: Date(),
            failures: failures
        )
    }

    private func runActions(
        _ actions: [WorkflowAction],
        context: ExecutionContext,
        executionStack: [UUID]
    ) async -> [ActionFailure] {
        guard !actions.isEmpty else {
            return [ActionFailure(actionTitle: "워크플로 실행", message: AutomationError.workflowIsEmpty.localizedDescription)]
        }
        for action in actions {
            currentActionTitle = action.title
            do {
                try Task.checkCancellation()
                switch action {
                case .launchApplication(let bundleIdentifier, _):
                    context.inputTarget = try await applications.launch(bundleIdentifier: bundleIdentifier, activates: true)

                case .openURL(let url):
                    context.inputTarget = try await applications.openURL(url)

                case .wait(let seconds):
                    guard seconds.isFinite, seconds > 0, seconds <= 30 else {
                        throw AutomationError.invalidWaitDuration
                    }
                    try await Task.sleep(for: .seconds(seconds))

                case .copyTemplate(let templateID, let mode):
                    guard store.templates.contains(where: { $0.id == templateID }) else {
                        throw AutomationError.templateNotFound
                    }
                    let document = store.templateDocument(id: templateID)
                    try clipboard.copy(document)
                    if mode == .copyAndPaste {
                        try await clipboard.paste(into: context.inputTarget)
                    }

                case .applyLayout(let layoutID):
                    guard let layout = store.layouts.first(where: { $0.id == layoutID }) else {
                        throw AutomationError.layoutNotFound
                    }
                    let failures = await layouts.apply(layout)
                    try Task.checkCancellation()
                    if !failures.isEmpty {
                        return failures.map {
                            ActionFailure(actionTitle: "\(action.title) · \($0.actionTitle)", message: $0.message)
                        }
                    }

                case .pressKey(let key):
                    try await keyboard.press(key, into: context.inputTarget)

                case .runWorkflow(let workflowID):
                    guard !executionStack.contains(workflowID) else {
                        throw AutomationError.workflowCycleDetected
                    }
                    guard let nestedWorkflow = store.workflows.first(where: { $0.id == workflowID }) else {
                        throw AutomationError.workflowNotFound
                    }
                    let failures = await runActions(
                        nestedWorkflow.actions,
                        context: context,
                        executionStack: executionStack + [workflowID]
                    )
                    if !failures.isEmpty {
                        return failures.map {
                            ActionFailure(actionTitle: "\(nestedWorkflow.name) · \($0.actionTitle)", message: $0.message)
                        }
                    }

                case .pasteImages(let filePaths):
                    try clipboard.copyImages(at: filePaths)
                    try await clipboard.paste(into: context.inputTarget)

                case .pasteFiles(let filePaths):
                    try clipboard.copyFiles(at: filePaths)
                    try await clipboard.paste(into: context.inputTarget)
                }
                try Task.checkCancellation()
            } catch {
                // Later actions depend on the preceding target, clipboard and focus.
                // In particular, never send Enter after a failed launch or paste.
                let message = error is CancellationError ? "실행을 중단했습니다." : error.localizedDescription
                return [ActionFailure(actionTitle: action.title, message: message)]
            }
        }

        return []
    }
}
