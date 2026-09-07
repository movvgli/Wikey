import Foundation
import Observation

@MainActor
@Observable
public final class WikeyRuntime {
    public let store: WikeyStore
    public let permissions: PermissionCenter
    public let loginItem: LoginItemService
    public let applications: ApplicationController
    public let clipboard: ClipboardService
    public let keyboard: KeyboardService
    public let layoutController: WindowLayoutController
    public let hotkeys: HotkeyRegistrar
    public let runner: WorkflowRunner
    public let iCloudSync: ICloudSyncService

    public private(set) var lastRun: RunSummary?
    public private(set) var applicationLaunchErrors: [UUID: String] = [:]
    public private(set) var hasStarted = false
    @ObservationIgnored private var applicationRunIDs: [String: UUID] = [:]
    @ObservationIgnored private var applicationRunNames: [UUID: String] = [:]

    public init(storeRootURL: URL? = nil) {
        let store = WikeyStore(rootURL: storeRootURL)
        let applications = ApplicationController()
        let clipboard = ClipboardService()
        let keyboard = KeyboardService()
        let layoutController = WindowLayoutController(applications: applications)
        let hotkeys = HotkeyRegistrar()

        self.store = store
        self.iCloudSync = ICloudSyncService(store: store)
        self.permissions = PermissionCenter()
        self.loginItem = LoginItemService()
        self.applications = applications
        self.clipboard = clipboard
        self.keyboard = keyboard
        self.layoutController = layoutController
        self.hotkeys = hotkeys
        self.runner = WorkflowRunner(
            store: store,
            applications: applications,
            clipboard: clipboard,
            keyboard: keyboard,
            layouts: layoutController
        )

        hotkeys.onWorkflow = { [weak runner = self.runner] id in
            Task { @MainActor in runner?.submit(workflowID: id) }
        }
        hotkeys.onApplication = { [weak self] id in
            Task { @MainActor in
                self?.launchApplicationShortcut(id: id)
            }
        }
        hotkeys.onLayout = { [weak self] id in
            Task { @MainActor in self?.run(layoutID: id) }
        }
        self.runner.onSummary = { [weak self] summary in
            self?.lastRun = summary
            if let self, let id = summary.workflowID,
               self.store.applicationShortcuts.contains(where: { $0.id == id })
                || self.applicationRunIDs.values.contains(id) {
                self.applicationLaunchErrors[id] = summary.failures.first?.message
            }
        }
        iCloudSync.canApply = { [weak self] in
            guard let self else { return false }
            return self.runner.runningWorkflowID == nil && self.runner.queuedWorkflowIDs.isEmpty
        }
        iCloudSync.onApply = { [weak self] in self?.reloadHotkeys() }
    }

    public func start() {
        guard !hasStarted else { return }
        store.load()
        layoutController.loadDisplayMappings(from: store.storageURL)
        reloadHotkeys()
        permissions.refresh()
        loginItem.refresh()
        hasStarted = true
        iCloudSync.start()
    }

    public func saveAndReloadHotkeys() {
        store.save()
        reloadHotkeys()
    }

    public func reloadHotkeys() {
        hotkeys.configure(
            workflows: store.workflows,
            applicationShortcuts: store.applicationShortcuts,
            layouts: store.layouts
        )
    }

    public func run(workflowID: UUID) {
        runner.submit(workflowID: workflowID)
    }

    public func run(layoutID: UUID) {
        guard let layout = store.layouts.first(where: { $0.id == layoutID }) else { return }
        runner.submit(workflow: Workflow(
            id: layout.id, name: layout.name,
            actions: [.applyLayout(layoutID: layout.id)]
        ))
    }

    public func runApplication(bundleIdentifier: String, displayName: String) {
        let id = store.applicationShortcuts.first { $0.bundleIdentifier == bundleIdentifier }?.id
            ?? applicationRunIDs[bundleIdentifier] ?? UUID()
        applicationRunIDs[bundleIdentifier] = id
        applicationRunNames[id] = displayName
        applicationLaunchErrors[id] = nil
        runner.submit(workflow: Workflow(
            id: id, name: displayName,
            actions: [.launchApplication(bundleIdentifier: bundleIdentifier, displayName: displayName)]
        ))
    }

    public func applicationRunID(bundleIdentifier: String) -> UUID? {
        store.applicationShortcuts.first { $0.bundleIdentifier == bundleIdentifier }?.id
            ?? applicationRunIDs[bundleIdentifier]
    }

    public func applicationLaunchError(bundleIdentifier: String) -> String? {
        guard let id = applicationRunID(bundleIdentifier: bundleIdentifier) else { return nil }
        return applicationLaunchErrors[id]
    }

    public func applicationName(runID: UUID) -> String? {
        store.applicationShortcuts.first { $0.id == runID }?.displayName
            ?? applicationRunNames[runID]
    }

    public func setApplicationShortcut(
        bundleIdentifier: String,
        displayName: String,
        shortcut: ShortcutGesture
    ) {
        let previousID = applicationRunID(bundleIdentifier: bundleIdentifier)
        store.setApplicationShortcut(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            shortcut: shortcut
        )
        if let previousID {
            applicationLaunchErrors[previousID] = nil
            applicationRunNames[previousID] = nil
        }
        applicationRunIDs[bundleIdentifier] = nil
        reloadHotkeys()
    }

    private func launchApplicationShortcut(id: UUID) {
        guard let application = store.applicationShortcuts.first(where: { $0.id == id }) else { return }
        runApplication(bundleIdentifier: application.bundleIdentifier, displayName: application.displayName)
    }
}
